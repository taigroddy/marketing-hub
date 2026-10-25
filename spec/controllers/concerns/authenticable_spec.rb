# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Authenticable, type: :controller do
  # Anonymous controller to test Authenticable integration
  controller(ActionController::Base) do
    include Authenticable

    before_action :authenticate_user!, only: [ :protected_action ]

    def protected_action
      user_id = Current.user.is_a?(Hash) ? Current.user[:id] : Current.user.id
      email = Current.user.is_a?(Hash) ? Current.user[:email] : Current.user.email
      render json: { message: "Hello #{user_id}", current_user_id: user_id, email: email }, status: :ok
    end

    def unprotected_action
      render json: { message: 'Public action' }, status: :ok
    end
  end

  before do
    routes.draw do
      get 'protected_action' => 'anonymous#protected_action'
      get 'unprotected_action' => 'anonymous#unprotected_action'
    end
    request.headers['Accept'] = 'application/json'
    Current.reset
  end

  after do
    Current.reset
  end

  describe 'JWT helpers' do
    describe '.encode_jwt and .decode_jwt' do
      it 'encodes and decodes payload with indifferent access' do
        token = Authenticable.encode_jwt({ user_id: 42, role: 'admin' })
        expect(token).to be_a(String)

        decoded = Authenticable.decode_jwt(token)
        expect(decoded[:user_id]).to eq(42)
        expect(decoded['user_id']).to eq(42)
        expect(decoded[:role]).to eq('admin')
        expect(decoded[:exp]).to be_present
      end

      it 'returns nil for nil or blank token' do
        expect(Authenticable.decode_jwt(nil)).to be_nil
        expect(Authenticable.decode_jwt('')).to be_nil
        expect(Authenticable.decode_jwt('   ')).to be_nil
      end

      it 'returns nil for invalid/tampered token or input raising ArgumentError' do
        expect(Authenticable.decode_jwt('invalid.jwt.token')).to be_nil
        expect(Authenticable.decode_jwt(12345)).to be_nil
      end

      it 'returns nil for expired token' do
        expired_token = Authenticable.encode_jwt({ user_id: 42 }, 1.hour.ago)
        expect(Authenticable.decode_jwt(expired_token)).to be_nil
      end

      it 'preserves existing exp in payload if already provided' do
        custom_exp = 2.hours.from_now.to_i
        token = Authenticable.encode_jwt({ user_id: 99, exp: custom_exp })
        decoded = Authenticable.decode_jwt(token)
        expect(decoded[:exp]).to eq(custom_exp)
      end
    end

    describe 'class methods on controller class' do
      it 'provides encode_jwt and decode_jwt on the controller class' do
        token = controller.class.encode_jwt({ user_id: 200 })
        expect(token).to be_a(String)
        decoded = controller.class.decode_jwt(token)
        expect(decoded[:user_id]).to eq(200)
      end
    end

    describe 'instance helpers inside controller' do
      it 'provides encode_jwt and decode_jwt methods on controller instances' do
        token = controller.encode_jwt({ user_id: 100 })
        expect(token).to be_a(String)
        decoded = controller.decode_jwt(token)
        expect(decoded[:user_id]).to eq(100)
      end

      it 'delegates current_user to Current.user' do
        Current.user = { id: 777 }
        expect(controller.current_user).to eq({ id: 777 })
      end
    end
  end

  describe '#authenticate_user!' do
    let(:user_payload) { { user_id: 123, email: 'test@example.com' } }
    let(:valid_token) { Authenticable.encode_jwt(user_payload) }

    context 'when User model is not defined' do
      before do
        hide_const('User')
      end

      context 'when valid Bearer token is provided in Authorization header' do
        it 'authenticates request, sets Current.user, and succeeds' do
          request.headers['Authorization'] = "Bearer #{valid_token}"
          get :protected_action

          expect(response).to have_http_status(:ok)
          json = JSON.parse(response.body)
          expect(json['message']).to eq('Hello 123')
          expect(json['current_user_id']).to eq(123)

          Current.reset
          controller.authenticate_user!
          expect(Current.user['user_id']).to eq(123)
        end
      end

      context 'when valid token is provided in cookies[:jwt_token]' do
        it 'authenticates request, sets Current.user from cookie, and succeeds' do
          cookies[:jwt_token] = valid_token
          get :protected_action

          expect(response).to have_http_status(:ok)
          json = JSON.parse(response.body)
          expect(json['message']).to eq('Hello 123')
          expect(json['current_user_id']).to eq(123)

          Current.reset
          controller.authenticate_user!
          expect(Current.user['user_id']).to eq(123)
        end
      end

      context 'when token has blank user identifier' do
        it 'renders unauthorized when user_id and sub are missing' do
          token = Authenticable.encode_jwt({ some_other_data: 123 })
          request.headers['Authorization'] = "Bearer #{token}"
          get :protected_action

          expect(response).to have_http_status(:unauthorized)
          expect(Current.user).to be_nil
        end
      end

      context 'when request is to an api endpoint route' do
        it 'renders JSON unauthorized response' do
          request.path = '/api/v1/protected_action'
          get :protected_action

          expect(response).to have_http_status(:unauthorized)
          json = JSON.parse(response.body)
          expect(json['error']).to eq('Unauthorized')
        end
      end

      context 'when Authorization header has sub instead of user_id' do
        it 'authenticates using sub as user_id fallback' do
          token = Authenticable.encode_jwt({ sub: 'user_999' })
          request.headers['Authorization'] = "Bearer #{token}"
          get :protected_action

          expect(response).to have_http_status(:ok)
          json = JSON.parse(response.body)
          expect(json['message']).to eq('Hello user_999')
        end
      end
    end

    context 'when User model exists in database' do
      let!(:db_user) do
        User.create!(
          email: 'found_user@example.com',
          password: 'Password123!',
          confirmed_at: Time.current
        )
      end

      it 'resolves Current.user to the ActiveRecord User instance when found' do
        token = Authenticable.encode_jwt({ user_id: db_user.id })
        request.headers['Authorization'] = "Bearer #{token}"
        get :protected_action

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['message']).to eq("Hello #{db_user.id}")
        expect(json['email']).to eq('found_user@example.com')

        # Also test direct authenticate_user! method to verify Current.user assignment before Rails request reset
        Current.reset
        controller.authenticate_user!
        expect(Current.user).to eq(db_user)
        expect(Current.user.email).to eq('found_user@example.com')
      end

      it 'renders unauthorized when user is not found in database' do
        non_existent_id = User.maximum(:id).to_i + 99_999
        token = Authenticable.encode_jwt({ user_id: non_existent_id })
        request.headers['Authorization'] = "Bearer #{token}"
        get :protected_action

        expect(response).to have_http_status(:unauthorized)
        expect(Current.user).to be_nil
      end
    end

    context 'when Authorization header is malformed' do
      it 'renders unauthorized for non-Bearer format' do
        request.headers['Authorization'] = "Basic #{valid_token}"
        get :protected_action

        expect(response).to have_http_status(:unauthorized)
        expect(Current.user).to be_nil
      end
    end

    context 'when token is expired' do
      it 'renders unauthorized' do
        expired_token = Authenticable.encode_jwt(user_payload, 10.minutes.ago)
        request.headers['Authorization'] = "Bearer #{expired_token}"
        get :protected_action

        expect(response).to have_http_status(:unauthorized)
        expect(Current.user).to be_nil
      end
    end

    context 'when token is missing' do
      it 'renders unauthorized for JSON format' do
        request.headers['Accept'] = 'application/json'
        get :protected_action

        expect(response).to have_http_status(:unauthorized)
        json = JSON.parse(response.body)
        expect(json['error']).to eq('Unauthorized')
        expect(Current.user).to be_nil
      end

      it 'renders unauthorized for HTML format when login_path is not defined' do
        controller.singleton_class.undef_method(:login_path) if controller.respond_to?(:login_path)
        request.headers['Accept'] = 'text/html'
        get :protected_action

        expect(response).to have_http_status(:unauthorized)
        expect(response.body).to include('Unauthorized')
      end

      context 'when login_path route is defined' do
        it 'redirects to login_path for HTML format' do
          request.headers['Accept'] = 'text/html'
          get :protected_action

          expect(response).to redirect_to(login_path)
          expect(flash[:alert]).to eq('Please sign in to continue.')
        end
      end
    end
  end

  describe 'cookie-based auto-refresh and token revocation' do
    include ActiveSupport::Testing::TimeHelpers

    let!(:db_user) do
      User.create!(
        email: 'authenticable_real@example.com',
        password: 'Password123!',
        confirmed_at: 1.day.ago
      )
    end
    let!(:token_pair) { UserToken.create_for_user!(db_user, device_info: 'Browser Web') }
    let(:user_token) { token_pair.first }
    let(:raw_refresh_token) { token_pair.last }

    context 'when access token is expired but refresh token cookie is valid' do
      it 'auto-refreshes access token and rewrites cookies' do
        expired_jwt = Authenticable.encode_jwt({ user_id: db_user.id, user_token_id: user_token.id }, 10.minutes.ago)
        cookies[:jwt_token] = expired_jwt
        cookies[:refresh_token] = raw_refresh_token

        get :protected_action

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['current_user_id']).to eq(db_user.id)
        expect(cookies[:jwt_token]).to be_present
        expect(cookies[:jwt_token]).not_to eq(expired_jwt)
        expect(cookies[:refresh_token]).to be_present
        expect(cookies[:refresh_token]).not_to eq(raw_refresh_token)

        new_decoded = Authenticable.decode_jwt(cookies[:jwt_token])
        expect(new_decoded[:user_id]).to eq(db_user.id)
        expect(new_decoded[:user_token_id]).to eq(user_token.id)
      end
    end

    context 'when access token cookie is missing but refresh token cookie is valid' do
      it 'issues a new access token and authenticates the request' do
        cookies[:refresh_token] = raw_refresh_token

        get :protected_action

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['current_user_id']).to eq(db_user.id)
        expect(cookies[:jwt_token]).to be_present
      end
    end

    context 'when refresh token is revoked' do
      it 'clears cookies and renders unauthorized' do
        user_token.revoke!
        cookies[:jwt_token] = Authenticable.encode_jwt({ user_id: db_user.id, user_token_id: user_token.id }, 10.minutes.ago)
        cookies[:refresh_token] = raw_refresh_token

        get :protected_action

        expect(response).to have_http_status(:unauthorized)
        expect(cookies[:jwt_token]).to be_blank
        expect(cookies[:refresh_token]).to be_blank
        expect(Current.user).to be_nil
      end
    end

    context 'when refresh token is expired' do
      it 'clears cookies and renders unauthorized' do
        travel_to 31.days.from_now do
          cookies[:jwt_token] = Authenticable.encode_jwt({ user_id: db_user.id, user_token_id: user_token.id }, 10.minutes.ago)
          cookies[:refresh_token] = raw_refresh_token

          get :protected_action

          expect(response).to have_http_status(:unauthorized)
          expect(cookies[:jwt_token]).to be_blank
          expect(cookies[:refresh_token]).to be_blank
          expect(Current.user).to be_nil
        end
      end
    end

    context 'when access token has a revoked user_token_id' do
      it 'rejects access and cleans up cookies' do
        user_token.revoke!
        valid_jwt = Authenticable.encode_jwt({ user_id: db_user.id, user_token_id: user_token.id })
        cookies[:jwt_token] = valid_jwt
        cookies[:refresh_token] = raw_refresh_token

        get :protected_action

        expect(response).to have_http_status(:unauthorized)
        expect(cookies[:jwt_token]).to be_blank
        expect(cookies[:refresh_token]).to be_blank
      end
    end

    context 'when Authorization header is expired and cookies are present' do
      it 'does not auto-refresh cookies and rejects request' do
        expired_jwt = Authenticable.encode_jwt({ user_id: db_user.id }, 10.minutes.ago)
        request.headers['Authorization'] = "Bearer #{expired_jwt}"
        cookies[:refresh_token] = raw_refresh_token

        get :protected_action

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end

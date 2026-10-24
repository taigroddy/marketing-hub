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
    allow(controller).to receive(:respond_to?).and_call_original
    allow(controller).to receive(:respond_to?).with(:login_path).and_return(false)
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
        allow(JWT).to receive(:decode).and_raise(ArgumentError.new('Invalid argument'))
        expect(Authenticable.decode_jwt('any.token.here')).to be_nil
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
      let(:mock_user_class) do
        Class.new do
          attr_accessor :id, :email

          def initialize(id, email)
            @id = id
            @email = email
          end

          def self.find_by(id:)
            id == 456 ? new(456, 'found@example.com') : nil
          end
        end
      end

      before do
        stub_const('User', mock_user_class)
      end

      it 'resolves Current.user to the ActiveRecord User instance when found' do
        token = Authenticable.encode_jwt({ user_id: 456 })
        request.headers['Authorization'] = "Bearer #{token}"
        get :protected_action

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['message']).to eq('Hello 456')
        expect(json['email']).to eq('found@example.com')

        # Also test direct authenticate_user! method to verify Current.user assignment before Rails request reset
        Current.reset
        controller.authenticate_user!
        expect(Current.user).to be_a(mock_user_class)
        expect(Current.user.email).to eq('found@example.com')
      end

      it 'renders unauthorized when user is not found in database' do
        token = Authenticable.encode_jwt({ user_id: 999 })
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
        request.headers['Accept'] = 'text/html'
        get :protected_action

        expect(response).to have_http_status(:unauthorized)
        expect(response.body).to include('Unauthorized')
      end

      context 'when login_path route is defined' do
        before do
          allow(controller).to receive(:respond_to?).with(:login_path).and_return(true)
          controller.define_singleton_method(:login_path) { '/login' }
        end

        it 'redirects to login_path for HTML format' do
          request.headers['Accept'] = 'text/html'
          get :protected_action

          expect(response).to redirect_to('/login')
          expect(flash[:alert]).to eq('Please sign in to continue.')
        end
      end
    end
  end
end

# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TokenAuthenticable, type: :controller do
  controller(ActionController::API) do
    include TokenAuthenticable

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
    Current.reset
  end

  after do
    Current.reset
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
          expect(controller.current_user['user_id']).to eq(123)
        end
      end

      context 'when valid token is provided in params[:token]' do
        it 'authenticates via params token fallback' do
          get :protected_action, params: { token: valid_token }

          expect(response).to have_http_status(:ok)
          json = JSON.parse(response.body)
          expect(json['current_user_id']).to eq(123)
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

      context 'when token is missing' do
        it 'renders JSON unauthorized response' do
          get :protected_action

          expect(response).to have_http_status(:unauthorized)
          json = JSON.parse(response.body)
          expect(json['success']).to be false
          expect(json['errors']).to eq(I18n.t('errors.unauthorized'))
        end
      end

      context 'when Authorization header is malformed' do
        it 'renders unauthorized for non-Bearer format' do
          request.headers['Authorization'] = "Basic #{valid_token}"
          get :protected_action

          expect(response).to have_http_status(:unauthorized)
          json = JSON.parse(response.body)
          expect(json['success']).to be false
        end
      end

      context 'when token is expired' do
        it 'renders unauthorized' do
          expired = Authenticable.encode_jwt(user_payload, 1.hour.ago)
          request.headers['Authorization'] = "Bearer #{expired}"
          get :protected_action

          expect(response).to have_http_status(:unauthorized)
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
    end

    context 'when User model exists in database' do
      let!(:db_user) do
        User.create!(
          email: 'token_spec_user@example.com',
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
        expect(json['current_user_id']).to eq(db_user.id)
        expect(json['email']).to eq(db_user.email)
      end

      it 'renders unauthorized when user is not found in database' do
        token = Authenticable.encode_jwt({ user_id: 999_999_999 })
        request.headers['Authorization'] = "Bearer #{token}"
        get :protected_action

        expect(response).to have_http_status(:unauthorized)
      end

      it 'exposes current_user_token_payload and current_user_token_id' do
        token_pair = UserToken.create_for_user!(db_user)
        user_token = token_pair.first
        token = Authenticable.encode_jwt({ user_id: db_user.id, user_token_id: user_token.id })

        request.headers['Authorization'] = "Bearer #{token}"
        get :protected_action

        expect(controller.current_user_token_id).to eq(user_token.id)
        expect(controller.current_user_token_payload[:user_id]).to eq(db_user.id)
      end

      it 'rejects access when token has a revoked user_token_id' do
        token_pair = UserToken.create_for_user!(db_user)
        user_token = token_pair.first
        token = Authenticable.encode_jwt({ user_id: db_user.id, user_token_id: user_token.id })

        user_token.revoke!

        request.headers['Authorization'] = "Bearer #{token}"
        get :protected_action

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end

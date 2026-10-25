# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SessionAuthenticable, type: :controller do
  controller(ActionController::Base) do
    include SessionAuthenticable

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
      get 'login' => 'anonymous#unprotected_action'
    end
    Current.reset
  end

  after do
    Current.reset
  end

  describe '#authenticate_user!' do
    let(:user_payload) { { user_id: 123, email: 'session_test@example.com' } }
    let(:valid_token) { Authenticable.encode_jwt(user_payload) }

    context 'when User model is not defined' do
      before do
        hide_const('User')
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
          expect(controller.current_user['user_id']).to eq(123)
          expect(controller.current_user_token).to eq(valid_token)
        end
      end

      context 'when token is missing' do
        it 'redirects to login_path for HTML requests' do
          get :protected_action
          expect(response).to redirect_to('/login')
        end

        it 'renders JSON unauthorized response for JSON requests' do
          request.headers['Accept'] = 'application/json'
          get :protected_action

          expect(response).to have_http_status(:unauthorized)
          json = JSON.parse(response.body)
          expect(json['success']).to be false
          expect(json['errors']).to eq(I18n.t('errors.unauthorized'))
        end
      end
    end

    context 'cookie-based auto-refresh and token revocation' do
      let!(:db_user) do
        User.create!(
          email: 'cookie_refresh_user@example.com',
          password: 'Password123!',
          confirmed_at: Time.current
        )
      end

      let!(:user_token_pair) { UserToken.create_for_user!(db_user) }
      let!(:user_token) { user_token_pair.first }
      let!(:raw_refresh_token) { user_token_pair.last }
      let!(:valid_jwt) do
        Authenticable.encode_jwt({ user_id: db_user.id, user_token_id: user_token.id })
      end
      let!(:expired_jwt) do
        Authenticable.encode_jwt({ user_id: db_user.id, user_token_id: user_token.id }, 10.minutes.ago)
      end

      it 'auto-refreshes access token and rewrites cookies when access token is expired but refresh token is valid' do
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
      end

      it 'issues a new access token and authenticates the request when access token cookie is missing' do
        cookies[:refresh_token] = raw_refresh_token

        get :protected_action

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['current_user_id']).to eq(db_user.id)
        expect(cookies[:jwt_token]).to be_present
      end

      it 'clears cookies and renders unauthorized when refresh token is revoked' do
        user_token.revoke!
        cookies[:jwt_token] = Authenticable.encode_jwt({ user_id: db_user.id, user_token_id: user_token.id }, 10.minutes.ago)
        cookies[:refresh_token] = raw_refresh_token

        get :protected_action

        expect(response).to redirect_to('/login')
        expect(cookies[:jwt_token]).to be_blank
        expect(cookies[:refresh_token]).to be_blank
      end

      it 'clears cookies when refresh token is expired' do
        user_token.update_columns(expires_at: 10.days.ago)
        cookies[:jwt_token] = Authenticable.encode_jwt({ user_id: db_user.id, user_token_id: user_token.id }, 10.minutes.ago)
        cookies[:refresh_token] = raw_refresh_token

        get :protected_action

        expect(response).to redirect_to('/login')
        expect(cookies[:jwt_token]).to be_blank
        expect(cookies[:refresh_token]).to be_blank
      end

      it 'rejects access and cleans up cookies when access token has a revoked user_token_id' do
        user_token.revoke!
        cookies[:jwt_token] = valid_jwt
        cookies[:refresh_token] = raw_refresh_token

        get :protected_action

        expect(response).to redirect_to('/login')
        expect(cookies[:jwt_token]).to be_blank
        expect(cookies[:refresh_token]).to be_blank
      end
    end
  end
end

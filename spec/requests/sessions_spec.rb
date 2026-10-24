# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Sessions', type: :request do
  include ActiveSupport::Testing::TimeHelpers

  let!(:user) do
    User.create!(
      email: 'member@example.com',
      password: 'Password123!',
      confirmed_at: 1.day.ago
    )
  end

  describe 'GET /login' do
    it 'renders the login page' do
      get '/login'
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Sign In')
      expect(response.body).to include('Email Address')
    end

    it 'redirects to /dashboard if already logged in' do
      token = Authenticable.encode_jwt({ user_id: user.id })
      cookies[:jwt_token] = token

      get '/login'
      expect(response).to redirect_to('/dashboard')
    end

    it 'auto-refreshes and redirects to /dashboard when access token expired but refresh token is valid' do
      token_pair = UserToken.create_for_user!(user)
      raw_refresh = token_pair.last
      expired_token = Authenticable.encode_jwt({ user_id: user.id, user_token_id: token_pair.first.id }, 10.minutes.ago)

      cookies[:jwt_token] = expired_token
      cookies[:refresh_token] = raw_refresh

      get '/login'
      expect(response).to redirect_to('/dashboard')
      expect(cookies[:jwt_token]).to be_present
      expect(cookies[:jwt_token]).not_to eq(expired_token)
    end
  end

  describe 'POST /login' do
    context 'with valid credentials' do
      it 'sets jwt_token and refresh_token cookies, creates UserToken, and redirects to /dashboard' do
        expect do
          post '/login',
               params: { email: 'member@example.com', password: 'Password123!' },
               headers: { 'User-Agent' => 'MarketingHub Browser' }
        end.to change(UserToken, :count).by(1)

        expect(response).to redirect_to('/dashboard')
        expect(cookies[:jwt_token]).to be_present
        expect(cookies[:refresh_token]).to be_present

        decoded = Authenticable.decode_jwt(cookies[:jwt_token])
        expect(decoded[:user_id]).to eq(user.id)
        expect(decoded[:user_token_id]).to be_present

        db_token = UserToken.find(decoded[:user_token_id])
        expect(db_token.token_digest).to eq(UserToken.digest(cookies[:refresh_token]))
        expect(db_token.device_info).to eq('MarketingHub Browser')
        expect(db_token.active?).to be true

        set_cookie_headers = Array(response.headers['set-cookie'] || response.headers['Set-Cookie'])
        refresh_cookie_header = set_cookie_headers.find { |header| header.start_with?('refresh_token=') }
        expect(refresh_cookie_header).to be_present
        expect(refresh_cookie_header).to include('expires=')
        expect(refresh_cookie_header).to include('httponly')
        expect(refresh_cookie_header).to include('samesite=lax')
      end

      it 'handles User-Agent exceeding 255 characters by truncating device_info' do
        long_user_agent = 'MarketingHub-Client/1.0 ' + ('U' * 300)
        post '/login',
             params: { email: 'member@example.com', password: 'Password123!' },
             headers: { 'User-Agent' => long_user_agent }

        expect(response).to redirect_to('/dashboard')
        decoded = Authenticable.decode_jwt(cookies[:jwt_token])
        db_token = UserToken.find(decoded[:user_token_id])
        expect(db_token.device_info.length).to eq(255)
        expect(db_token.device_info).to eq(long_user_agent[0, 255])
      end
    end

    context 'with invalid credentials' do
      it 'renders new template with 422 unprocessable entity' do
        post '/login', params: { email: 'member@example.com', password: 'WrongPassword' }

        expect(response).to have_http_status(:unprocessable_content)
        expect(cookies[:jwt_token]).to be_blank
        expect(cookies[:refresh_token]).to be_blank
        expect(flash[:alert]).to include('Invalid email or password')
      end
    end

    context 'when user is not confirmed' do
      let!(:unconfirmed) do
        User.create!(
          email: 'unconfirmed@example.com',
          password: 'Password123!',
          confirmation_token: 'tok'
        )
      end

      it 'renders new template with 422 unprocessable entity' do
        post '/login', params: { email: 'unconfirmed@example.com', password: 'Password123!' }

        expect(response).to have_http_status(:unprocessable_content)
        expect(cookies[:jwt_token]).to be_blank
        expect(cookies[:refresh_token]).to be_blank
        expect(flash[:alert]).to include('Please confirm your email')
      end
    end
  end

  describe 'DELETE /logout' do
    it 'clears cookies, revokes the user token row, and redirects to /login' do
      token_pair = UserToken.create_for_user!(user, device_info: 'Device A')
      user_token = token_pair.first
      raw_refresh = token_pair.last
      token = Authenticable.encode_jwt({ user_id: user.id, user_token_id: user_token.id })

      cookies[:jwt_token] = token
      cookies[:refresh_token] = raw_refresh

      delete '/logout'

      expect(response).to redirect_to('/login')
      expect(cookies[:jwt_token]).to be_blank
      expect(cookies[:refresh_token]).to be_blank

      expect(user_token.reload.revoked?).to be true
      expect(user_token.active?).to be false
    end

    it 'revoking on device A leaves device B session intact' do
      token_a_pair = UserToken.create_for_user!(user, device_info: 'Device A')
      token_b_pair = UserToken.create_for_user!(user, device_info: 'Device B')

      cookies[:jwt_token] = Authenticable.encode_jwt({ user_id: user.id, user_token_id: token_a_pair.first.id })
      cookies[:refresh_token] = token_a_pair.last

      delete '/logout'

      expect(token_a_pair.first.reload.revoked?).to be true
      expect(token_b_pair.first.reload.active?).to be true
    end
  end
end

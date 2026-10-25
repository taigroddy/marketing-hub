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
      expect(response.body).to include(I18n.t('sessions.new.title'))
      expect(response.body).to include(I18n.t('sessions.new.email_label'))
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

    it 'clears cookies and renders the login page when params[:logout] is present' do
      token = Authenticable.encode_jwt({ user_id: user.id })
      cookies[:jwt_token] = token

      get '/login', params: { logout: '1' }
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t('sessions.new.title'))
      expect(response.cookies['jwt_token']).to be_blank
    end
  end
end

# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Dashboard', type: :request do
  let!(:user) do
    User.create!(
      email: 'dash-user@example.com',
      password: 'Password123!',
      confirmed_at: 1.day.ago
    )
  end

  describe 'GET /dashboard' do
    context 'when authenticated via cookie' do
      it 'renders the dashboard with platform accounts section and empty state' do
        token = Authenticable.encode_jwt({ user_id: user.id })
        cookies[:jwt_token] = token

        get '/dashboard'
        expect(response).to have_http_status(:ok)
        expect(response.body).to include('Dashboard')
        expect(response.body).to include('dash-user@example.com')
        expect(response.body).to include('Tài khoản quảng cáo (Platform Accounts)')
        expect(response.body).to include('Chưa có tài khoản quảng cáo nào được liên kết')
        expect(response.body).to include('Liên kết mới')
        expect(response.body).to include('data-controller="oauth-connect"')
        expect(response.body).to include('data-action="click->oauth-connect#connect"')
        expect(response.body).to include('data-platform="facebook"')
        expect(response.body).to include('Sắp ra mắt')
      end

      it 'renders platform accounts list when user has connected accounts' do
        PlatformAccount::Facebook.create!(
          user: user,
          account_id: 'act_445566',
          name: 'Growth Ads Account',
          access_token: 'secret_token_123',
          status: 'connected'
        )

        token = Authenticable.encode_jwt({ user_id: user.id })
        cookies[:jwt_token] = token

        get '/dashboard'
        expect(response).to have_http_status(:ok)
        expect(response.body).to include('Growth Ads Account')
        expect(response.body).to include('act_445566')
        expect(response.body).to include('Facebook')
        expect(response.body).to include('Đã kết nối')
      end

      it 'renders top navbar with user email, sign out button, and language switcher' do
        token = Authenticable.encode_jwt({ user_id: user.id })
        cookies[:jwt_token] = token

        get '/dashboard'
        expect(response).to have_http_status(:ok)
        expect(response.body).to include('Marketing Hub')
        expect(response.body).to include('dash-user@example.com')
        expect(response.body).to include('Đăng xuất')
        expect(response.body).to include("setLanguage('en')")
        expect(response.body).to include("setLanguage('vi')")
      end

      it 'switches language to EN when locale cookie is set to en' do
        token = Authenticable.encode_jwt({ user_id: user.id })
        cookies[:jwt_token] = token
        cookies[:locale] = 'en'

        get '/dashboard'
        expect(response).to have_http_status(:ok)
        expect(response.body).to include('Sign Out')
        expect(response.body).to include('Platform Accounts')
        expect(response.body).to include('Create New')
      end
    end

    context 'when unauthenticated' do
      it 'redirects to /login' do
        get '/dashboard'
        expect(response).to redirect_to('/login')
        expect(flash[:alert]).to eq(I18n.t('auth.sign_in_required'))
      end
    end
  end
end

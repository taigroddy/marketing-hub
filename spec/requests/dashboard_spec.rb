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
      it 'renders the dashboard' do
        token = Authenticable.encode_jwt({ user_id: user.id })
        cookies[:jwt_token] = token

        get '/dashboard'
        expect(response).to have_http_status(:ok)
        expect(response.body).to include('Dashboard')
        expect(response.body).to include('dash-user@example.com')
      end
    end

    context 'when unauthenticated' do
      it 'redirects to /login' do
        get '/dashboard'
        expect(response).to redirect_to('/login')
        expect(flash[:alert]).to include('Please sign in')
      end
    end
  end
end

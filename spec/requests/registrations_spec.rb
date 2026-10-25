# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Registrations', type: :request do
  include ActiveJob::TestHelper

  describe 'GET /register' do
    it 'renders the registration form' do
      get '/register'
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Create Account')
      expect(response.body).to include('Email Address')
    end

    it 'redirects to /dashboard if already logged in' do
      user = User.create!(email: 'current@example.com', password: 'Password123!', confirmed_at: Time.current)
      token = Authenticable.encode_jwt({ user_id: user.id })
      cookies[:jwt_token] = token

      get '/register'
      expect(response).to redirect_to('/dashboard')
    end
  end
end

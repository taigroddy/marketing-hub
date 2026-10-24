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

  describe 'POST /register' do
    let(:valid_params) do
      {
        email: 'register-web@example.com',
        password: 'Password123!',
        password_confirmation: 'Password123!'
      }
    end

    context 'with valid parameters' do
      it 'creates user, enqueues email, and redirects to /login with notice' do
        expect do
          post '/register', params: valid_params
        end.to change(User, :count).by(1)
           .and have_enqueued_mail(UserMailer, :confirmation_email)

        expect(response).to redirect_to('/login')
        expect(flash[:notice]).to include('Please check your email')
      end
    end

    context 'with invalid parameters' do
      it 'renders new template with 422 unprocessable entity' do
        post '/register', params: valid_params.merge(password_confirmation: 'mismatch')

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include('must match password')
      end
    end
  end
end

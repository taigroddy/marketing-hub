# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Sessions', type: :request do
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
  end

  describe 'POST /login' do
    context 'with valid credentials' do
      it 'sets jwt_token cookie and redirects to /dashboard' do
        post '/login', params: { email: 'member@example.com', password: 'Password123!' }

        expect(response).to redirect_to('/dashboard')
        expect(cookies[:jwt_token]).to be_present
        decoded = Authenticable.decode_jwt(cookies[:jwt_token])
        expect(decoded[:user_id]).to eq(user.id)
      end
    end

    context 'with invalid credentials' do
      it 'renders new template with 422 unprocessable entity' do
        post '/login', params: { email: 'member@example.com', password: 'WrongPassword' }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(cookies[:jwt_token]).to be_blank
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

        expect(response).to have_http_status(:unprocessable_entity)
        expect(cookies[:jwt_token]).to be_blank
        expect(flash[:alert]).to include('Please confirm your email')
      end
    end
  end

  describe 'DELETE /logout' do
    it 'clears the cookie and redirects to /login' do
      token = Authenticable.encode_jwt({ user_id: user.id })
      cookies[:jwt_token] = token

      delete '/logout'
      expect(response).to redirect_to('/login')
      expect(cookies[:jwt_token]).to be_blank
    end
  end
end

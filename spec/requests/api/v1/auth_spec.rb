# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::Auth', type: :request do
  include ActiveJob::TestHelper

  describe 'POST /api/v1/auth/register' do
    let(:valid_attributes) do
      {
        email: 'api-user@example.com',
        password: 'Password123!',
        password_confirmation: 'Password123!'
      }
    end

    context 'with valid parameters' do
      it 'creates user, returns 201 created with user blueprint, and enqueues confirmation mail' do
        expect do
          post '/api/v1/auth/register', params: valid_attributes, as: :json
        end.to change(User, :count).by(1)
           .and have_enqueued_mail(UserMailer, :confirmation_email)

        expect(response).to have_http_status(:created)
        json = JSON.parse(response.body)
        expect(json['message']).to include('Registration successful')
        expect(json['user']).to include(
          'id' => a_kind_of(Integer),
          'email' => 'api-user@example.com'
        )
        expect(json['user']).not_to have_key('password_digest')
        expect(json['user']).not_to have_key('confirmation_token')
      end
    end

    context 'with duplicate email' do
      before do
        User.create!(
          email: 'api-user@example.com',
          password: 'Password123!',
          confirmation_token: 'tok-abc'
        )
      end

      it 'returns 422 unprocessable entity with errors' do
        expect do
          post '/api/v1/auth/register', params: valid_attributes, as: :json
        end.not_to change(User, :count)

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json['errors']['email']).to include('has already been taken')
      end
    end

    context 'with invalid parameters' do
      it 'returns 422 when email is invalid' do
        post '/api/v1/auth/register', params: valid_attributes.merge(email: 'invalid'), as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json['errors']['email']).to be_present
      end

      it 'returns 422 when password confirmation does not match' do
        post '/api/v1/auth/register', params: valid_attributes.merge(password_confirmation: 'nomatch'), as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json['errors']['password_confirmation']).to include('must match password')
      end
    end
  end

  describe 'POST /api/v1/auth/login' do
    let!(:user) do
      User.create!(
        email: 'login-user@example.com',
        password: 'Password123!',
        confirmed_at: 1.day.ago
      )
    end

    context 'with valid credentials for confirmed user' do
      it 'returns 200 ok with JWT token and user blueprint' do
        post '/api/v1/auth/login', params: { email: 'login-user@example.com', password: 'Password123!' }, as: :json

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['token']).to be_present
        expect(json['user']['id']).to eq(user.id)
        expect(json['user']['email']).to eq('login-user@example.com')

        decoded = Authenticable.decode_jwt(json['token'])
        expect(decoded[:user_id]).to eq(user.id)
      end
    end

    context 'when user is not confirmed' do
      let!(:unconfirmed) do
        User.create!(
          email: 'unconfirmed@example.com',
          password: 'Password123!',
          confirmation_token: 'token-unconf'
        )
      end

      it 'returns 403 forbidden with unconfirmed message' do
        post '/api/v1/auth/login', params: { email: 'unconfirmed@example.com', password: 'Password123!' }, as: :json

        expect(response).to have_http_status(:forbidden)
        json = JSON.parse(response.body)
        expect(json['error']).to include('confirm your email')
      end
    end

    context 'with invalid password' do
      it 'returns 401 unauthorized' do
        post '/api/v1/auth/login', params: { email: 'login-user@example.com', password: 'WrongPassword!' }, as: :json

        expect(response).to have_http_status(:unauthorized)
        json = JSON.parse(response.body)
        expect(json['error']).to include('Invalid email or password')
      end
    end

    context 'with non-existent email' do
      it 'returns 401 unauthorized' do
        post '/api/v1/auth/login', params: { email: 'unknown@example.com', password: 'Password123!' }, as: :json

        expect(response).to have_http_status(:unauthorized)
        json = JSON.parse(response.body)
        expect(json['error']).to include('Invalid email or password')
      end
    end

    context 'with invalid payload format' do
      it 'returns 422 unprocessable entity' do
        post '/api/v1/auth/login', params: { email: 'invalid-email', password: '' }, as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json['errors']).to be_present
      end
    end
  end

  describe 'GET /api/v1/auth/confirm_email/:token' do
    let!(:user) do
      User.create!(
        email: 'confirm-target@example.com',
        password: 'Password123!',
        confirmation_token: 'secret-email-token-123',
        confirmation_sent_at: 10.minutes.ago
      )
    end

    context 'with valid token' do
      it 'activates user, returns 200 with JWT and user blueprint' do
        get '/api/v1/auth/confirm_email/secret-email-token-123', as: :json

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['token']).to be_present
        expect(json['user']['id']).to eq(user.id)
        expect(json['message']).to include('Email confirmed successfully')

        user.reload
        expect(user.confirmed?).to be true
        expect(user.confirmation_token).to be_nil
      end
    end

    context 'with invalid token' do
      it 'returns 422 unprocessable entity' do
        get '/api/v1/auth/confirm_email/wrong-token', as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json['error']).to include('Invalid or expired')
      end
    end
  end

  describe 'GET /api/v1/auth/me' do
    let!(:user) do
      User.create!(
        email: 'me-test@example.com',
        password: 'Password123!',
        confirmed_at: 1.day.ago
      )
    end
    let(:token) { Authenticable.encode_jwt({ user_id: user.id }) }

    context 'with valid authorization token' do
      it 'returns current user blueprint' do
        get '/api/v1/auth/me', headers: { 'Authorization' => "Bearer #{token}" }, as: :json

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['user']['id']).to eq(user.id)
        expect(json['user']['email']).to eq('me-test@example.com')
      end
    end

    context 'without authorization token' do
      it 'returns 401 unauthorized' do
        get '/api/v1/auth/me', as: :json

        expect(response).to have_http_status(:unauthorized)
        json = JSON.parse(response.body)
        expect(json['error']).to eq('Unauthorized')
      end
    end
  end
end

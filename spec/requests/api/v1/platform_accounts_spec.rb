# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::PlatformAccounts', type: :request do
  let(:user) do
    User.create!(
      email: 'user-platform-req@example.com',
      password: 'Password123!',
      confirmed_at: Time.current
    )
  end

  let(:jwt_token) { Authenticable.encode_jwt({ user_id: user.id }) }
  let(:headers) { { 'Authorization' => "Bearer #{jwt_token}", 'Accept' => 'application/json' } }

  describe 'Route constraints' do
    it 'rejects unsupported platforms with 404 not found' do
      get '/v1/unsupported_platform/oauth/authorize', headers: headers
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'GET /v1/:platform/oauth/authorize' do
    context 'when unauthenticated' do
      it 'returns 401 unauthorized' do
        get '/v1/facebook/oauth/authorize', headers: { 'Accept' => 'application/json' }
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when authenticated with Facebook platform' do
      it 'returns authorize_url in json format' do
        get '/v1/facebook/oauth/authorize', headers: headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['authorize_url']).to include('https://www.facebook.com/v21.0/dialog/oauth')
        expect(json['authorize_url']).to include('client_id=')
      end

      it 'redirects to facebook OAuth dialog in html format' do
        get '/v1/facebook/oauth/authorize',
            headers: { 'Authorization' => "Bearer #{jwt_token}", 'Accept' => 'text/html' }

        expect(response).to have_http_status(:found)
        expect(response.location).to include('https://www.facebook.com/v21.0/dialog/oauth')
      end
    end

    context 'when authenticated with Google platform' do
      it 'returns 501 not implemented' do
        get '/v1/google/oauth/authorize', headers: headers

        expect(response).to have_http_status(:not_implemented)
        json = JSON.parse(response.body)
        expect(json['error']).to include('Google platform integration coming soon')
      end
    end
  end

  describe 'GET /v1/:platform/oauth/callback' do
    let(:mock_client) { instance_double(Clients::OAuth::FacebookClient) }

    before do
      allow(Clients::OAuth::FacebookClient).to receive(:new).and_return(mock_client)
    end

    context 'when unauthenticated' do
      it 'returns 401 unauthorized' do
        get '/v1/facebook/oauth/callback', params: { code: 'some_code' }, headers: { 'Accept' => 'application/json' }
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when validation fails' do
      it 'returns 422 unprocessable_entity when code is missing' do
        get '/v1/facebook/oauth/callback', headers: headers

        expect(response).to have_http_status(:unprocessable_content)
        json = JSON.parse(response.body)
        expect(json['errors']).to be_present
        expect(json['errors']['code']).to include('is missing')
      end
    end

    context 'when Google platform callback is invoked' do
      it 'returns 422 unprocessable_entity' do
        get '/v1/google/oauth/callback', params: { code: 'google_code' }, headers: headers

        expect(response).to have_http_status(:unprocessable_content)
        json = JSON.parse(response.body)
        expect(json['error']).to include('Google platform integration coming soon')
      end
    end

    context 'when Facebook OAuth code exchange succeeds' do
      before do
        allow(mock_client).to receive(:exchange_code).with(code: 'valid_fb_code', redirect_uri: nil).and_return(
          Dry::Monads::Success(
            access_token: 'eaab_valid_token_xyz',
            token_type: 'bearer',
            expires_in: 5184000
          )
        )
        allow(mock_client).to receive(:fetch_ad_accounts).with('eaab_valid_token_xyz').and_return(
          Dry::Monads::Success(
            data: [
              { 'id' => 'act_99887766', 'account_id' => '99887766', 'name' => 'Marketing Ad Account' }
            ]
          )
        )
      end

      it 'returns 200 with PlatformAccountBlueprint json format' do
        get '/v1/facebook/oauth/callback', params: { code: 'valid_fb_code' }, headers: headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['message']).to eq('Platform account connected successfully')

        account_json = json['platform_account']
        expect(account_json['id']).to be_present
        expect(account_json['user_id']).to eq(user.id)
        expect(account_json['type']).to eq('PlatformAccount::Facebook')
        expect(account_json['account_id']).to eq('99887766')
        expect(account_json['name']).to eq('Marketing Ad Account')
        expect(account_json['status']).to eq('connected')

        # Never leak tokens in the blueprint
        expect(account_json).not_to have_key('access_token')
        expect(account_json).not_to have_key('refresh_token')
      end

      it 'redirects to dashboard when requested as HTML' do
        get '/v1/facebook/oauth/callback',
            params: { code: 'valid_fb_code' },
            headers: { 'Authorization' => "Bearer #{jwt_token}", 'Accept' => 'text/html' }

        expect(response).to redirect_to(dashboard_path)
        expect(flash[:notice]).to include('kết nối thành công')
      end

      it 'also works via /api/v1/facebook/oauth/callback route' do
        get '/api/v1/facebook/oauth/callback', params: { code: 'valid_fb_code' }, headers: headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['platform_account']['account_id']).to eq('99887766')
      end
    end

    context 'when Facebook OAuth code exchange fails' do
      before do
        allow(mock_client).to receive(:exchange_code).with(code: 'invalid_fb_code', redirect_uri: nil).and_return(
          Dry::Monads::Failure(error: 'Invalid verification code format.')
        )
      end

      it 'returns 422 with error message' do
        get '/v1/facebook/oauth/callback', params: { code: 'invalid_fb_code' }, headers: headers

        expect(response).to have_http_status(:unprocessable_content)
        json = JSON.parse(response.body)
        expect(json['error']).to eq('Invalid verification code format.')
      end

      it 'redirects to dashboard with alert on failure when requested as HTML' do
        get '/v1/facebook/oauth/callback',
            params: { code: 'invalid_fb_code' },
            headers: { 'Authorization' => "Bearer #{jwt_token}", 'Accept' => 'text/html' }

        expect(response).to redirect_to(dashboard_path)
        expect(flash[:alert]).to include('Kết nối thất bại')
      end

      it 'redirects to dashboard with alert on validation error when requested as HTML' do
        get '/v1/facebook/oauth/callback',
            headers: { 'Authorization' => "Bearer #{jwt_token}", 'Accept' => 'text/html' }

        expect(response).to redirect_to(dashboard_path)
        expect(flash[:alert]).to include('Kết nối thất bại')
      end
    end
  end

  describe 'GET /api/v1/platform_accounts' do
    let!(:fb_account) do
      PlatformAccount::Facebook.create!(
        user: user,
        account_id: 'act_123',
        name: 'My FB',
        access_token: 'token_123',
        status: 'connected'
      )
    end

    it 'returns user platform accounts' do
      get '/api/v1/platform_accounts', headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['platform_accounts']).to be_an(Array)
      expect(json['platform_accounts'].first['account_id']).to eq('act_123')
    end
  end
end

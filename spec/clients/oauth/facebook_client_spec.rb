# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Clients::OAuth::FacebookClient, type: :client do
  let(:app_id) { '2893197974374504' }
  let(:app_secret) { '1a419b58b12969bc50991f7cac6195e6' }
  let(:redirect_uri) { 'http://marketing.localhost/oauth/facebook/callback' }
  let(:client) { described_class.new(app_id: app_id, app_secret: app_secret, redirect_uri: redirect_uri) }

  describe 'constants and aliases' do
    it 'aliases OAuth::FacebookClient to Clients::OAuth::FacebookClient' do
      expect(described_class).to eq(OAuth::FacebookClient)
    end

    it 'inherits from OAuth::BaseClient' do
      expect(described_class.superclass).to eq(OAuth::BaseClient)
    end
  end

  describe '#initialize' do
    it 'falls back to ENV variables when parameters are nil' do
      client_from_env = described_class.new
      expect(client_from_env.app_id).to eq(ENV['FB_APP_ID'])
      expect(client_from_env.app_secret).to eq(ENV['FB_APP_SECRET'])
      expect(client_from_env.redirect_uri).to eq(ENV['FB_AUTHORIZE_REDIRECT_URI'] || ENV['FB_AUTHORIZE_REDIRECT_UI'])
    end

    it 'falls back to FB_AUTHORIZE_REDIRECT_UI when FB_AUTHORIZE_REDIRECT_URI is nil' do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with('FB_AUTHORIZE_REDIRECT_URI').and_return(nil)
      allow(ENV).to receive(:[]).with('FB_AUTHORIZE_REDIRECT_UI').and_return('http://custom.ui/callback')

      client_fallback = described_class.new(app_id: 'id', app_secret: 'sec', redirect_uri: nil)
      expect(client_fallback.redirect_uri).to eq('http://custom.ui/callback')
    end
  end

  describe '#authorize_url' do
    it 'generates a valid Facebook OAuth dialog URL' do
      url = client.authorize_url(state: 'csrf_xyz')
      uri = URI.parse(url)

      expect(uri.scheme).to eq('https')
      expect(uri.host).to eq('www.facebook.com')
      expect(uri.path).to eq('/v21.0/dialog/oauth')

      query = Rack::Utils.parse_query(uri.query)
      expect(query['client_id']).to eq(app_id)
      expect(query['redirect_uri']).to eq(redirect_uri)
      expect(query['response_type']).to eq('code')
      expect(query['state']).to eq('csrf_xyz')
      expect(query['scope']).to include('ads_management')
    end

    it 'allows overriding redirect_uri and scope' do
      url = client.authorize_url(redirect_uri: 'http://custom.com/cb', scope: 'email')
      query = Rack::Utils.parse_query(URI.parse(url).query)

      expect(query['redirect_uri']).to eq('http://custom.com/cb')
      expect(query['scope']).to eq('email')
      expect(query['state']).to be_nil
    end
  end

  describe '#exchange_code', vcr: { cassette_name: 'facebook_oauth' } do
    context 'when authorization code is valid' do
      it 'returns Success with access_token' do
        result = client.exchange_code(code: 'valid_auth_code')

        expect(result).to be_success
        data = result.value!
        expect(data[:access_token]).to eq('mock_access_token_fb_123456')
        expect(data[:token_type]).to eq('bearer')
        expect(data[:expires_in]).to eq(5184000)
      end

      it 'supports positional code argument' do
        result = client.exchange_code('valid_auth_code')

        expect(result).to be_success
        expect(result.value![:access_token]).to eq('mock_access_token_fb_123456')
      end
    end

    context 'when code is blank or missing' do
      it 'returns Failure or raises ArgumentError' do
        expect { client.exchange_code(code: '') }.to raise_error(ArgumentError, /code/)
      end
    end

    context 'when Facebook API returns an error' do
      it 'returns Failure with error details' do
        result = client.exchange_code(code: 'invalid_code')

        expect(result).to be_failure
        expect(result.failure[:error]).to include('Invalid verification code')
      end
    end

    context 'when network connection fails' do
      before do
        allow(Net::HTTP).to receive(:start).and_raise(SocketError.new('Failed to connect'))
      end

      it 'returns Failure with exception message' do
        result = client.exchange_code(code: 'valid_auth_code')

        expect(result).to be_failure
        expect(result.failure[:error]).to include('Failed to connect')
      end
    end

    context 'when response is non-JSON' do
      before do
        fake_response = instance_double(Net::HTTPInternalServerError, is_a?: false, code: '500', body: 'Service Unavailable')
        allow(Net::HTTP).to receive(:start).and_return(fake_response)
      end

      it 'returns Failure with HTTP error' do
        result = client.exchange_code(code: 'valid_auth_code')

        expect(result).to be_failure
        expect(result.failure[:error]).to eq('HTTP 500 Error')
      end
    end
  end

  describe '#refresh_token', vcr: { cassette_name: 'facebook_oauth' } do
    context 'when token is valid' do
      it 'exchanges token for a long-lived access token and returns Success' do
        result = client.refresh_token(refresh_token: 'short_lived_token')

        expect(result).to be_success
        data = result.value!
        expect(data[:access_token]).to eq('mock_long_lived_token_fb_789')
        expect(data[:token_type]).to eq('bearer')
      end

      it 'supports positional token argument' do
        result = client.refresh_token('short_lived_token')

        expect(result).to be_success
        expect(result.value![:access_token]).to eq('mock_long_lived_token_fb_789')
      end
    end

    context 'when token is blank' do
      it 'raises ArgumentError' do
        expect { client.refresh_token(refresh_token: '') }.to raise_error(ArgumentError, /token/)
      end
    end

    context 'when Facebook API returns an error on refresh' do
      it 'returns Failure with error details' do
        result = client.refresh_token(refresh_token: 'expired_or_invalid_token')

        expect(result).to be_failure
        expect(result.failure[:error]).to include('Error validating access token')
      end
    end
  end

  describe '#fetch_user_info' do
    it 'raises ArgumentError when access_token is blank' do
      expect { client.fetch_user_info('') }.to raise_error(ArgumentError, /access_token/)
    end

    it 'performs GET to /me and returns Success' do
      stub_request(:get, 'https://graph.facebook.com/v21.0/me?access_token=token123&fields=id,name')
        .to_return(status: 200, body: '{"id":"fb_user_1","name":"Test User"}', headers: { 'Content-Type' => 'application/json' })

      result = client.fetch_user_info('token123')
      expect(result).to be_success
      expect(result.value![:id]).to eq('fb_user_1')
      expect(result.value![:name]).to eq('Test User')
    end
  end

  describe '#fetch_ad_accounts' do
    it 'raises ArgumentError when access_token is blank' do
      expect { client.fetch_ad_accounts('') }.to raise_error(ArgumentError, /access_token/)
    end

    it 'performs GET to /me/adaccounts and returns Success' do
      stub_request(:get, 'https://graph.facebook.com/v21.0/me/adaccounts?access_token=token123&fields=id,name,account_id')
        .to_return(status: 200, body: '{"data":[{"id":"act_123","account_id":"123","name":"Ad Account 1"}]}', headers: { 'Content-Type' => 'application/json' })

      result = client.fetch_ad_accounts('token123')
      expect(result).to be_success
      expect(result.value![:data]).to be_an(Array)
      expect(result.value![:data].first['account_id']).to eq('123')
    end
  end
end

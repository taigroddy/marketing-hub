# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PlatformAccounts::ConnectService, type: :service do
  let(:user) do
    User.create!(
      email: 'user-connect@example.com',
      password: 'Password123!',
      confirmed_at: Time.current
    )
  end

  before do
    Current.user = user
  end

  after do
    Current.user = nil
  end

  describe 'validations' do
    it 'returns failure when platform is missing' do
      result = described_class.call(code: 'some_code')

      expect(result).to be_failure
      expect(result.failure[:platform]).to include('is missing')
    end

    it 'returns failure when code is blank' do
      result = described_class.call(platform: 'facebook', code: '')

      expect(result).to be_failure
      expect(result.failure[:code]).to include('must be filled')
    end
  end

  describe 'authentication check' do
    it 'returns failure :unauthorized when no user is logged in' do
      Current.user = nil
      result = described_class.call(platform: 'facebook', code: 'valid_code')

      expect(result).to be_failure
      expect(result.failure).to eq(:unauthorized)
    end
  end

  describe 'google platform integration' do
    it 'returns failure indicating google is not yet supported' do
      result = described_class.call(platform: 'google', code: 'valid_code')

      expect(result).to be_failure
      expect(result.failure[:error]).to include('Google platform integration coming soon')
    end
  end

  describe 'facebook connection flow' do
    let(:mock_client) { instance_double(Clients::OAuth::FacebookClient) }

    before do
      allow(Clients::OAuth::FacebookClient).to receive(:new).and_return(mock_client)
    end

    context 'when OAuth code exchange fails' do
      before do
        allow(mock_client).to receive(:exchange_code).with(code: 'bad_code', redirect_uri: nil).and_return(
          Dry::Monads::Failure(error: 'Invalid verification code format.')
        )
      end

      it 'returns failure with error message' do
        result = described_class.call(platform: 'facebook', code: 'bad_code')

        expect(result).to be_failure
        expect(result.failure[:error]).to eq('Invalid verification code format.')
        expect(PlatformAccount.count).to eq(0)
      end
    end

    context 'when OAuth code exchange succeeds' do
      let(:token_response) do
        {
          access_token: 'eaab_fb_mock_access_token_123',
          token_type: 'bearer',
          expires_in: 5184000
        }
      end

      before do
        allow(mock_client).to receive(:exchange_code).with(code: 'valid_code', redirect_uri: nil).and_return(
          Dry::Monads::Success(token_response)
        )
        allow(mock_client).to receive(:fetch_ad_accounts).with('eaab_fb_mock_access_token_123').and_return(
          Dry::Monads::Success(
            data: [
              { 'id' => 'act_1015012345678', 'account_id' => '1015012345678', 'name' => 'Acme Corp Ads' }
            ]
          )
        )
      end

      it 'creates a new PlatformAccount::Facebook record' do
        result = described_class.call(platform: 'facebook', code: 'valid_code')

        expect(result).to be_success
        account = result.value![:platform_account]

        expect(account).to be_a(PlatformAccount::Facebook)
        expect(account.user).to eq(user)
        expect(account.account_id).to eq('1015012345678')
        expect(account.name).to eq('Acme Corp Ads')
        expect(account.access_token).to eq('eaab_fb_mock_access_token_123')
        expect(account.status).to eq('connected')
        expect(account.token_expires_at).to be_within(5.seconds).of(Time.current + 5184000.seconds)
      end

      it 'upserts existing account when re-authenticating same account_id' do
        existing = PlatformAccount::Facebook.create!(
          user: user,
          account_id: '1015012345678',
          name: 'Old Name',
          access_token: 'old_access_token',
          status: 'disconnected'
        )

        expect do
          result = described_class.call(platform: 'facebook', code: 'valid_code')
          expect(result).to be_success
        end.not_to change(PlatformAccount, :count)

        existing.reload
        expect(existing.name).to eq('Acme Corp Ads')
        expect(existing.access_token).to eq('eaab_fb_mock_access_token_123')
        expect(existing.status).to eq('connected')
      end

      it 'allows overriding account_id and name directly from params' do
        result = described_class.call(
          platform: 'facebook',
          code: 'valid_code',
          account_id: 'custom_act_777',
          name: 'Custom Ad Account'
        )

        expect(result).to be_success
        account = result.value![:platform_account]
        expect(account.account_id).to eq('custom_act_777')
        expect(account.name).to eq('Custom Ad Account')
      end

      it 'falls back to user id when ad accounts are empty' do
        allow(mock_client).to receive(:fetch_ad_accounts).and_return(
          Dry::Monads::Success(data: [])
        )
        allow(mock_client).to receive(:fetch_user_info).and_return(
          Dry::Monads::Failure(error: 'Not found')
        )

        result = described_class.call(platform: 'facebook', code: 'valid_code')

        expect(result).to be_success
        account = result.value![:platform_account]
        expect(account.account_id).to eq("act_#{user.id}")
        expect(account.name).to eq('Facebook Ad Account')
      end
    end
  end
end

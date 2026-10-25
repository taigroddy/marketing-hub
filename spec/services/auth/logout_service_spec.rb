# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Auth::LogoutService do
  include ActiveSupport::Testing::TimeHelpers

  let(:user) do
    User.create!(
      email: 'logout_tester@example.com',
      password: 'Password123!',
      confirmed_at: 1.day.ago
    )
  end

  let!(:user_token_pair) { UserToken.create_for_user!(user, device_info: 'Device A') }
  let(:user_token) { user_token_pair.first }
  let(:raw_refresh_token) { user_token_pair.last }

  describe '.call' do
    context 'with a valid active refresh token' do
      it 'revokes the token row and succeeds' do
        result = described_class.call(refresh_token: raw_refresh_token)

        expect(result).to be_success
        expect(result.value![:user_token].id).to eq(user_token.id)

        user_token.reload
        expect(user_token.revoked?).to be true
        expect(user_token.active?).to be false
        expect(user_token.revoked_at).to be_present
      end

      it 'revokes only the target device and leaves other devices active' do
        other_token_pair = UserToken.create_for_user!(user, device_info: 'Device B')
        other_user_token = other_token_pair.first

        result = described_class.call(refresh_token: raw_refresh_token)
        expect(result).to be_success

        expect(user_token.reload.revoked?).to be true
        expect(other_user_token.reload.active?).to be true
      end
    end

    context 'with a valid active user_token_id' do
      it 'revokes the token row and succeeds' do
        result = described_class.call(user_token_id: user_token.id)

        expect(result).to be_success
        expect(result.value![:user_token].id).to eq(user_token.id)
        expect(user_token.reload.revoked?).to be true
      end
    end

    context 'when validation fails' do
      it 'returns failure when refresh_token is missing' do
        result = described_class.call({})

        expect(result).to be_failure
        expect(result.failure[:refresh_token]).to be_present
      end

      it 'returns failure when refresh_token is blank' do
        result = described_class.call(refresh_token: '')

        expect(result).to be_failure
        expect(result.failure[:refresh_token]).to be_present
      end
    end

    context 'when token is not found in database' do
      it 'returns failure with token_not_found' do
        result = described_class.call(refresh_token: 'invalid-nonexistent-token')

        expect(result).to be_failure
        expect(result.failure).to eq(:token_not_found)
      end
    end

    context 'when token is already revoked' do
      before do
        user_token.revoke!
      end

      it 'returns failure with token_revoked' do
        result = described_class.call(refresh_token: raw_refresh_token)

        expect(result).to be_failure
        expect(result.failure).to eq(:token_revoked)
      end
    end

    context 'when token is expired' do
      it 'returns failure with token_expired' do
        travel_to 31.days.from_now do
          result = described_class.call(refresh_token: raw_refresh_token)

          expect(result).to be_failure
          expect(result.failure).to eq(:token_expired)
        end
      end
    end
  end
end

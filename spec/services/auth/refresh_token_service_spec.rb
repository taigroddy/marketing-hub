# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Auth::RefreshTokenService do
  include ActiveSupport::Testing::TimeHelpers

  let(:user) do
    User.create!(
      email: 'refresh_tester@example.com',
      password: 'Password123!',
      confirmed_at: 1.day.ago
    )
  end

  let!(:user_token_pair) { UserToken.create_for_user!(user, device_info: 'Device A') }
  let(:user_token) { user_token_pair.first }
  let(:raw_refresh_token) { user_token_pair.last }

  describe '.call' do
    context 'with a valid active refresh token' do
      it 'issues a new access token and rotated refresh token' do
        result = described_class.call(refresh_token: raw_refresh_token)

        expect(result).to be_success
        data = result.value!
        expect(data[:user].id).to eq(user.id)
        expect(data[:token]).to be_a(String)
        expect(data[:refresh_token]).to be_a(String)
        expect(data[:refresh_token]).not_to eq(raw_refresh_token)

        decoded = Authenticable.decode_jwt(data[:token])
        expect(decoded[:user_id]).to eq(user.id)
        expect(decoded[:user_token_id]).to eq(user_token.id)

        user_token.reload
        expect(user_token.token_digest).to eq(UserToken.digest(data[:refresh_token]))
        expect(user_token.active?).to be true
      end

      it 'updates device_info on refresh when provided' do
        result = described_class.call(
          refresh_token: raw_refresh_token,
          device_info: 'Updated Browser Info'
        )

        expect(result).to be_success
        user_token.reload
        expect(user_token.device_info).to eq('Updated Browser Info')
      end

      it 'truncates device_info exceeding 255 characters on refresh' do
        long_ua = 'Mozilla/5.0 ' + ('w' * 300)
        result = described_class.call(
          refresh_token: raw_refresh_token,
          device_info: long_ua
        )

        expect(result).to be_success
        user_token.reload
        expect(user_token.device_info.length).to eq(255)
        expect(user_token.device_info).to eq(long_ua[0, 255])
      end

      it 'invalidates the previous refresh token after rotation' do
        first_refresh = described_class.call(refresh_token: raw_refresh_token)
        expect(first_refresh).to be_success

        second_attempt = described_class.call(refresh_token: raw_refresh_token)
        expect(second_attempt).to be_failure
        expect(second_attempt.failure).to eq(:token_not_found)
      end

      it 'does not affect other devices tokens for the same user' do
        other_token_pair = UserToken.create_for_user!(user, device_info: 'Device B')
        other_raw = other_token_pair.last

        result = described_class.call(refresh_token: raw_refresh_token)
        expect(result).to be_success

        other_token_record = other_token_pair.first.reload
        expect(other_token_record.active?).to be true
        expect(other_token_record.token_digest).to eq(UserToken.digest(other_raw))
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

    context 'when token does not exist in database' do
      it 'returns failure with token_not_found' do
        result = described_class.call(refresh_token: 'nonexistent-token')

        expect(result).to be_failure
        expect(result.failure).to eq(:token_not_found)
      end
    end

    context 'when token has been revoked' do
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

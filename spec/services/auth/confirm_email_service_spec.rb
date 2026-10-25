# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Auth::ConfirmEmailService do
  describe '.call' do
    let!(:user) do
      User.create!(
        email: 'unconfirmed@example.com',
        password: 'Password123!',
        confirmation_token: 'valid-confirm-token-xyz',
        confirmation_sent_at: 10.minutes.ago
      )
    end

    context 'with valid confirmation token' do
      it 'confirms user, clears token, and returns user and jwt token' do
        result = described_class.call(token: 'valid-confirm-token-xyz')

        expect(result).to be_success
        data = result.value!
        expect(data[:user].id).to eq(user.id)
        expect(data[:token]).to be_a(String)

        decoded = Authenticable.decode_jwt(data[:token])
        expect(decoded[:user_id]).to eq(user.id)

        user.reload
        expect(user.confirmed?).to be true
        expect(user.confirmation_token).to be_nil
      end
    end

    context 'when validation fails' do
      it 'returns failure when token is empty string' do
        result = described_class.call(token: '')
        expect(result).to be_failure
        expect(result.failure[:token]).to be_present
      end

      it 'returns failure when token is nil' do
        result = described_class.call(token: nil)
        expect(result).to be_failure
        expect(result.failure[:token]).to be_present
      end

      it 'returns failure when token is missing' do
        result = described_class.call({})
        expect(result).to be_failure
        expect(result.failure[:token]).to be_present
      end
    end

    context 'when token does not match any user' do
      it 'returns failure with invalid_token' do
        result = described_class.call(token: 'non-existent-token')
        expect(result).to be_failure
        expect(result.failure).to eq(:invalid_token)
      end
    end

    context 'when user is already confirmed' do
      let!(:confirmed_user) do
        User.create!(
          email: 'already-confirmed@example.com',
          password: 'Password123!',
          confirmation_token: 'old-token',
          confirmed_at: 1.day.ago
        )
      end

      it 'returns failure indicating already confirmed' do
        result = described_class.call(token: 'old-token')
        expect(result).to be_failure
        expect(result.failure).to eq(:already_confirmed)
      end
    end
    context 'when confirmation token is expired' do
      let!(:expired_user) do
        User.create!(
          email: 'expired@example.com',
          password: 'Password123!',
          confirmation_token: 'expired-token-999',
          confirmation_sent_at: 25.hours.ago
        )
      end

      it 'returns failure with resource_not_found when sent > 24 hours ago' do
        result = described_class.call(token: 'expired-token-999')
        expect(result).to be_failure
        expect(result.failure).to eq([ :resource_not_found, I18n.t('auth.invalid_confirmation_token') ])
        expect(expired_user.reload.confirmed?).to be false
      end

      it 'returns failure with resource_not_found when confirmation_sent_at is nil' do
        expired_user.update_column(:confirmation_sent_at, nil)
        result = described_class.call(token: 'expired-token-999')
        expect(result).to be_failure
        expect(result.failure).to eq([ :resource_not_found, I18n.t('auth.invalid_confirmation_token') ])
        expect(expired_user.reload.confirmed?).to be false
      end
    end
  end
end

# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Auth::LoginService do
  describe '.call' do
    let!(:user) do
      User.create!(
        email: 'member@example.com',
        password: 'Password123!',
        confirmed_at: 1.day.ago
      )
    end

    context 'with valid credentials for confirmed user' do
      it 'authenticates successfully and returns user, access token, and refresh token' do
        expect do
          result = described_class.call(email: 'member@example.com', password: 'Password123!')

          expect(result).to be_success
          data = result.value!
          expect(data[:user].id).to eq(user.id)
          expect(data[:token]).to be_a(String)
          expect(data[:refresh_token]).to be_a(String)

          decoded = Authenticable.decode_jwt(data[:token])
          expect(decoded[:user_id]).to eq(user.id)
          expect(decoded[:user_token_id]).to eq(data[:user_token].id)

          expect(data[:user_token].user_id).to eq(user.id)
          expect(data[:user_token].token_digest).to eq(UserToken.digest(data[:refresh_token]))
          expect(data[:user_token].active?).to be true
        end.to change(UserToken, :count).by(1)
      end

      it 'authenticates with case-insensitive email' do
        result = described_class.call(email: 'MEMBER@EXAMPLE.COM', password: 'Password123!')

        expect(result).to be_success
        expect(result.value![:user].id).to eq(user.id)
      end

      it 'records device_info when provided' do
        result = described_class.call(
          email: 'member@example.com',
          password: 'Password123!',
          device_info: 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0)'
        )

        expect(result).to be_success
        expect(result.value![:user_token].device_info).to eq('Mozilla/5.0 (iPhone; CPU iPhone OS 17_0)')
      end

      it 'truncates device_info exceeding 255 characters without error' do
        long_ua = 'Mozilla/5.0 ' + ('z' * 300)
        result = described_class.call(
          email: 'member@example.com',
          password: 'Password123!',
          device_info: long_ua
        )

        expect(result).to be_success
        expect(result.value![:user_token].device_info.length).to eq(255)
        expect(result.value![:user_token].device_info).to eq(long_ua[0, 255])
      end

      it 'creates independent token records on multiple logins across devices' do
        result_device_a = described_class.call(
          email: 'member@example.com',
          password: 'Password123!',
          device_info: 'Device A'
        )
        result_device_b = described_class.call(
          email: 'member@example.com',
          password: 'Password123!',
          device_info: 'Device B'
        )

        expect(result_device_a).to be_success
        expect(result_device_b).to be_success

        token_a = result_device_a.value![:user_token]
        token_b = result_device_b.value![:user_token]

        expect(token_a.id).not_to eq(token_b.id)
        expect(token_a.token_digest).not_to eq(token_b.token_digest)
        expect(token_a.device_info).to eq('Device A')
        expect(token_b.device_info).to eq('Device B')
      end
    end

    context 'when validation fails' do
      it 'returns failure with contract errors when email is invalid' do
        result = described_class.call(email: 'not-valid', password: 'Password123!')

        expect(result).to be_failure
        expect(result.failure[:email]).to include('is invalid')
      end

      it 'returns failure when password is blank' do
        result = described_class.call(email: 'member@example.com', password: '')

        expect(result).to be_failure
        expect(result.failure[:password]).to be_present
      end
    end

    context 'when user does not exist' do
      it 'returns failure with invalid_credentials' do
        result = described_class.call(email: 'nonexistent@example.com', password: 'Password123!')

        expect(result).to be_failure
        expect(result.failure).to eq(:invalid_credentials)
      end
    end

    context 'when password is wrong' do
      it 'returns failure with invalid_credentials' do
        result = described_class.call(email: 'member@example.com', password: 'WrongPassword!')

        expect(result).to be_failure
        expect(result.failure).to eq(:invalid_credentials)
      end
    end

    context 'when user is not confirmed' do
      let!(:unconfirmed_user) do
        User.create!(
          email: 'unconfirmed-login@example.com',
          password: 'Password123!',
          confirmation_token: 'tok-123'
        )
      end

      it 'returns failure with unconfirmed_email' do
        result = described_class.call(email: 'unconfirmed-login@example.com', password: 'Password123!')

        expect(result).to be_failure
        expect(result.failure).to eq(:unconfirmed_email)
      end
    end
  end
end

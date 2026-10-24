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
      it 'authenticates successfully and returns user and jwt token' do
        result = described_class.call(email: 'member@example.com', password: 'Password123!')

        expect(result).to be_success
        data = result.value!
        expect(data[:user].id).to eq(user.id)
        expect(data[:token]).to be_a(String)

        decoded = Authenticable.decode_jwt(data[:token])
        expect(decoded[:user_id]).to eq(user.id)
      end

      it 'authenticates with case-insensitive email' do
        result = described_class.call(email: 'MEMBER@EXAMPLE.COM', password: 'Password123!')

        expect(result).to be_success
        expect(result.value![:user].id).to eq(user.id)
      end

      it 'handles ActionController::Parameters input' do
        params = ActionController::Parameters.new(email: 'member@example.com', password: 'Password123!')
        result = described_class.call(params)

        expect(result).to be_success
        expect(result.value![:user].id).to eq(user.id)
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

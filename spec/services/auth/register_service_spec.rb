# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Auth::RegisterService do
  include ActiveJob::TestHelper

  describe '.call' do
    let(:valid_params) do
      {
        email: 'newuser@example.com',
        password: 'Password123!',
        password_confirmation: 'Password123!'
      }
    end

    context 'with valid parameters' do
      it 'creates a new user, generates confirmation token, and enqueues confirmation email' do
        result = nil
        expect do
          result = described_class.call(valid_params)
        end.to change(User, :count).by(1)
           .and have_enqueued_mail(UserMailer, :confirmation_email)

        expect(result).to be_success
        user = result.value![:user]
        expect(user.email).to eq('newuser@example.com')
        expect(user.confirmation_token).to be_present
        expect(user.confirmation_sent_at).to be_present
        expect(user.confirmed?).to be false
      end

      it 'normalizes email before creation' do
        result = described_class.call(
          email: '  SPACED@EXAMPLE.COM  ',
          password: 'Password123!',
          password_confirmation: 'Password123!'
        )

        expect(result).to be_success
        expect(result.value![:user].email).to eq('spaced@example.com')
      end

      it 'handles string-keyed hash from full_request_params' do
        params = valid_params.stringify_keys
        result = described_class.call(params)

        expect(result).to be_success
        expect(result.value![:user].email).to eq('newuser@example.com')
      end
    end

    context 'when user save fails unexpectedly' do
      it 'returns failure with user errors' do
        allow_any_instance_of(User).to receive(:save).and_return(false)
        allow_any_instance_of(User).to receive_message_chain(:errors, :to_h).and_return(base: [ 'Save failed' ])

        result = described_class.call(valid_params)
        expect(result).to be_failure
        expect(result.failure).to eq(base: [ 'Save failed' ])
      end
    end

    context 'when validation fails' do
      it 'returns failure with contract errors when email is invalid' do
        result = described_class.call(
          email: 'invalid-email',
          password: 'Password123!',
          password_confirmation: 'Password123!'
        )

        expect(result).to be_failure
        expect(result.failure[:email]).to include('is invalid')
      end

      it 'returns failure when password confirmation does not match' do
        result = described_class.call(
          email: 'user@example.com',
          password: 'Password123!',
          password_confirmation: 'Mismatch123!'
        )

        expect(result).to be_failure
        expect(result.failure[:password_confirmation]).to include('must match password')
      end
    end

    context 'when user email is already taken' do
      before do
        User.create!(
          email: 'existing@example.com',
          password: 'Password123!',
          confirmation_token: 'existing-token'
        )
      end

      it 'returns failure without creating duplicate or enqueuing email' do
        result = nil
        expect do
          result = described_class.call(
            email: 'EXISTING@example.com',
            password: 'NewPassword123!',
            password_confirmation: 'NewPassword123!'
          )
        end.to not_change(User, :count)
           .and not_have_enqueued_mail(UserMailer, :confirmation_email)

        expect(result).to be_failure
        expect(result.failure[:email]).to include('has already been taken')
      end
    end
  end
end

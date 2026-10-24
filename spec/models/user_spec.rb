# frozen_string_literal: true

require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'validations' do
    subject(:user) do
      described_class.new(
        email: 'user@example.com',
        password: 'Password123!',
        password_confirmation: 'Password123!'
      )
    end

    it 'is valid with valid attributes' do
      expect(user).to be_valid
    end

    it 'requires email to be present' do
      user.email = ''
      expect(user).not_to be_valid
      expect(user.errors[:email]).to include("can't be blank")
    end

    it 'validates email format' do
      user.email = 'invalid-email-format'
      expect(user).not_to be_valid
      expect(user.errors[:email]).to include('is invalid')
    end

    it 'enforces case-insensitive email uniqueness' do
      described_class.create!(
        email: 'user@example.com',
        password: 'Password123!',
        password_confirmation: 'Password123!'
      )

      duplicate_user = described_class.new(
        email: 'USER@EXAMPLE.COM',
        password: 'OtherPassword123!',
        password_confirmation: 'OtherPassword123!'
      )

      expect(duplicate_user).not_to be_valid
      expect(duplicate_user.errors[:email]).to include('has already been taken')
    end

    it 'requires password on creation' do
      invalid_user = described_class.new(email: 'user2@example.com')
      expect(invalid_user).not_to be_valid
      expect(invalid_user.errors[:password]).to be_present
    end

    it 'authenticates with correct password using has_secure_password' do
      expect(user.authenticate('Password123!')).to eq(user)
      expect(user.authenticate('WrongPassword')).to be(false)
    end
  end

  describe '#confirmed?' do
    let(:user) { described_class.new(email: 'user@example.com', password: 'Password123!') }

    it 'returns false when confirmed_at is nil' do
      user.confirmed_at = nil
      expect(user.confirmed?).to be false
    end

    it 'returns true when confirmed_at is set' do
      user.confirmed_at = Time.current
      expect(user.confirmed?).to be true
    end
  end

  describe '#confirm!' do
    let(:user) do
      described_class.create!(
        email: 'user@example.com',
        password: 'Password123!',
        confirmation_token: 'valid-token-123',
        confirmation_sent_at: 1.hour.ago
      )
    end

    it 'sets confirmed_at and clears confirmation_token' do
      expect(user.confirmed?).to be false
      expect(user.confirm!).to be true
      expect(user.reload.confirmed?).to be true
      expect(user.confirmed_at).to be_present
      expect(user.confirmation_token).to be_nil
    end
  end

  describe 'callbacks' do
    it 'does not trigger background jobs or mailers on save' do
      expect do
        described_class.create!(
          email: 'no-callback@example.com',
          password: 'Password123!',
          confirmation_token: 'token-abc'
        )
      end.not_to change(ActionMailer::Base.deliveries, :count)
    end
  end
end

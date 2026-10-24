# frozen_string_literal: true

require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'associations' do
    it 'has many campaigns with dependent destroy' do
      assoc = described_class.reflect_on_association(:campaigns)
      expect(assoc.macro).to eq(:has_many)
      expect(assoc.options[:dependent]).to eq(:destroy)
    end

    it 'has many platform_accounts with dependent destroy' do
      assoc = described_class.reflect_on_association(:platform_accounts)
      expect(assoc.macro).to eq(:has_many)
      expect(assoc.options[:dependent]).to eq(:destroy)
    end

    it 'has many user_tokens with dependent destroy' do
      assoc = described_class.reflect_on_association(:user_tokens)
      expect(assoc.macro).to eq(:has_many)
      expect(assoc.options[:dependent]).to eq(:destroy)
    end
  end

  describe 'authentication' do
    let(:user) do
      described_class.create!(
        email: 'user-auth@example.com',
        password: 'Password123!'
      )
    end

    it 'sets password_digest on create' do
      expect(user.password_digest).to be_present
      expect(user.password_digest).not_to eq('Password123!')
    end

    it 'authenticates with correct password using has_secure_password' do
      expect(user.authenticate('Password123!')).to eq(user)
      expect(user.authenticate('WrongPassword')).to be(false)
    end

    it 'does not enforce password presence at model validation level' do
      user_without_password = described_class.new(email: 'no-pwd@example.com')
      expect(user_without_password).to be_valid
    end
  end

  describe 'database constraints' do
    it 'raises ActiveRecord::NotNullViolation when email is null' do
      expect do
        described_class.create!(email: nil, password: 'Password123!')
      end.to raise_error(ActiveRecord::NotNullViolation)
    end

    it 'raises ActiveRecord::NotNullViolation when password_digest is null' do
      expect do
        described_class.create!(email: 'no-digest@example.com', password_digest: nil)
      end.to raise_error(ActiveRecord::NotNullViolation)
    end

    it 'raises ActiveRecord::RecordNotUnique on duplicate email' do
      described_class.create!(email: 'unique-check@example.com', password: 'Password123!')
      expect do
        described_class.create!(email: 'unique-check@example.com', password: 'OtherPassword123!')
      end.to raise_error(ActiveRecord::RecordNotUnique)
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
        email: 'user-confirm@example.com',
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
    it 'normalizes email by trimming whitespace and downcasing before save' do
      user = described_class.create!(email: '  USER-NORM@ExAmPlE.CoM  ', password: 'Password123!')
      expect(user.email).to eq('user-norm@example.com')
    end

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

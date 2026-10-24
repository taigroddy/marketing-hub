# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UserToken, type: :model do
  include ActiveSupport::Testing::TimeHelpers

  let(:user) do
    User.create!(
      email: 'tokentest@example.com',
      password: 'Password123!',
      confirmed_at: 1.day.ago
    )
  end

  describe 'associations' do
    it 'belongs to a user' do
      token, = described_class.create_for_user!(user)
      expect(token.user).to eq(user)
    end
  end

  describe '.create_for_user!' do
    it 'creates a persistent record and returns raw token' do
      token, raw = described_class.create_for_user!(user, device_info: 'Mobile Safari')

      expect(token).to be_persisted
      expect(token.user_id).to eq(user.id)
      expect(token.device_info).to eq('Mobile Safari')
      expect(token.token_digest).to eq(Digest::SHA256.hexdigest(raw))
      expect(token.expires_at).to be > 29.days.from_now
      expect(token.revoked_at).to be_nil
      expect(token.active?).to be true
    end
  end

  describe '.digest' do
    it 'computes SHA256 hexdigest of input' do
      expect(described_class.digest('my-token')).to eq(Digest::SHA256.hexdigest('my-token'))
    end
  end

  describe '.generate_token' do
    it 'generates a 64-character random hex token' do
      token1 = described_class.generate_token
      token2 = described_class.generate_token

      expect(token1).to be_a(String)
      expect(token1.length).to eq(64)
      expect(token1).not_to eq(token2)
    end
  end

  describe 'status predicates and lifecycle' do
    let!(:token_pair) { described_class.create_for_user!(user) }
    let(:token) { token_pair.first }
    let(:raw_token) { token_pair.last }

    it 'is active when newly created' do
      expect(token.active?).to be true
      expect(token.revoked?).to be false
      expect(token.expired?).to be false
    end

    it 'is revoked after revoke! is called' do
      token.revoke!

      expect(token.revoked_at).to be_present
      expect(token.revoked?).to be true
      expect(token.active?).to be false
    end

    it 'is expired when expires_at is past' do
      travel_to 31.days.from_now do
        expect(token.expired?).to be true
        expect(token.active?).to be false
      end
    end

    it 'rotates token digest and refreshes expires_at' do
      old_digest = token.token_digest
      old_expires_at = token.expires_at

      travel_to 1.day.from_now do
        new_raw = token.rotate!(new_device_info: 'Desktop Chrome')

        expect(new_raw).not_to eq(raw_token)
        expect(token.token_digest).not_to eq(old_digest)
        expect(token.token_digest).to eq(described_class.digest(new_raw))
        expect(token.device_info).to eq('Desktop Chrome')
        expect(token.expires_at).to be > old_expires_at
        expect(token.active?).to be true
      end
    end
  end

  describe '.active scope' do
    it 'returns only active tokens' do
      active_token, = described_class.create_for_user!(user)
      revoked_token, = described_class.create_for_user!(user)
      revoked_token.revoke!

      expired_token, = described_class.create_for_user!(user)
      expired_token.update_columns(expires_at: 1.hour.ago)

      active_tokens = described_class.active
      expect(active_tokens).to include(active_token)
      expect(active_tokens).not_to include(revoked_token)
      expect(active_tokens).not_to include(expired_token)
    end
  end

  describe 'uniqueness constraint' do
    it 'raises error on duplicate token_digest' do
      token, = described_class.create_for_user!(user)
      expect do
        described_class.create!(
          user: user,
          token_digest: token.token_digest,
          expires_at: 30.days.from_now
        )
      end.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end
end

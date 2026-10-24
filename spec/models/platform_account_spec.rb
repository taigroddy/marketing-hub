# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PlatformAccount, type: :model do
  let(:user) do
    User.create!(
      email: 'user-platform@example.com',
      password: 'Password123!',
      confirmed_at: Time.current
    )
  end

  let(:valid_attributes) do
    {
      user: user,
      type: 'PlatformAccount::Facebook',
      account_id: 'act_1234567890',
      name: 'My Facebook Ad Account',
      access_token: 'secret_token_fb_abc123',
      refresh_token: 'secret_refresh_token_fb_xyz456',
      token_expires_at: 60.days.from_now,
      refresh_token_expires_at: 90.days.from_now,
      status: 'connected'
    }
  end

  describe 'STI hierarchy' do
    it 'allows instantiating PlatformAccount::Facebook subclass' do
      fb_account = PlatformAccount::Facebook.new(valid_attributes.except(:type))
      expect(fb_account).to be_a(PlatformAccount)
      expect(fb_account).to be_a(PlatformAccount::Facebook)
      expect(fb_account.type).to eq('PlatformAccount::Facebook')
    end

    it 'allows instantiating PlatformAccount::Google subclass' do
      google_account = PlatformAccount::Google.new(valid_attributes.except(:type).merge(account_id: 'goog_987654'))
      expect(google_account).to be_a(PlatformAccount)
      expect(google_account).to be_a(PlatformAccount::Google)
      expect(google_account.type).to eq('PlatformAccount::Google')
    end
  end

  describe 'associations' do
    it 'belongs to a user' do
      account = described_class.new(valid_attributes)
      expect(account.user).to eq(user)
    end

    it 'is destroyed when user is destroyed' do
      account = described_class.create!(valid_attributes)
      expect { user.destroy }.to change(described_class, :count).by(-1)
    end
  end

  describe 'validations' do
    it 'is valid with valid attributes' do
      account = described_class.new(valid_attributes)
      expect(account).to be_valid
    end

    it 'requires account_id' do
      account = described_class.new(valid_attributes.merge(account_id: nil))
      expect(account).not_to be_valid
      expect(account.errors[:account_id]).to include("can't be blank")
    end

    it 'requires access_token' do
      account = described_class.new(valid_attributes.merge(access_token: nil))
      expect(account).not_to be_valid
      expect(account.errors[:access_token]).to include("can't be blank")
    end

    it 'requires status' do
      account = described_class.new(valid_attributes.merge(status: nil))
      expect(account).not_to be_valid
      expect(account.errors[:status]).to include("can't be blank")
    end

    it 'enforces uniqueness of account_id scoped to user and type' do
      described_class.create!(valid_attributes)
      duplicate = described_class.new(valid_attributes)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:account_id]).to include('has already been taken')
    end

    it 'allows same account_id for different users' do
      other_user = User.create!(
        email: 'other-user@example.com',
        password: 'Password123!',
        confirmed_at: Time.current
      )
      described_class.create!(valid_attributes)
      account_other = described_class.new(valid_attributes.merge(user: other_user))
      expect(account_other).to be_valid
    end

    it 'allows same account_id for different platform types' do
      described_class.create!(valid_attributes)
      google_account = PlatformAccount::Google.new(valid_attributes.except(:type))
      expect(google_account).to be_valid
    end
  end

  describe 'token encryption (ActiveRecord::Encryption)' do
    it 'encrypts access_token and refresh_token in database while returning plaintext in model' do
      raw_access_token = 'EAABsb7819238912389_super_secret_token'
      raw_refresh_token = 'REFRESH_TOKEN_998877_super_secret'

      account = described_class.create!(
        valid_attributes.merge(
          access_token: raw_access_token,
          refresh_token: raw_refresh_token
        )
      )

      # In-memory and reloaded instance provides plaintext
      reloaded = described_class.find(account.id)
      expect(reloaded.access_token).to eq(raw_access_token)
      expect(reloaded.refresh_token).to eq(raw_refresh_token)

      # Raw column data in database does NOT match plaintext
      raw_sql = "SELECT access_token, refresh_token FROM platform_accounts WHERE id = #{account.id}"
      raw_row = ActiveRecord::Base.connection.select_one(raw_sql)

      expect(raw_row['access_token']).not_to eq(raw_access_token)
      expect(raw_row['access_token']).not_to include(raw_access_token)
      expect(raw_row['refresh_token']).not_to eq(raw_refresh_token)
      expect(raw_row['refresh_token']).not_to include(raw_refresh_token)
    end
  end

  describe 'methods and scopes' do
    let!(:active_account) { described_class.create!(valid_attributes) }
    let!(:disconnected_account) do
      described_class.create!(valid_attributes.merge(account_id: 'act_999999', status: 'disconnected'))
    end

    it '.connected scope returns only connected accounts' do
      expect(described_class.connected).to include(active_account)
      expect(described_class.connected).not_to include(disconnected_account)
    end

    it '#connected? returns true if status is connected' do
      expect(active_account.connected?).to be true
      expect(disconnected_account.connected?).to be false
    end

    it '#expired? checks expiration of token' do
      active_account.update!(token_expires_at: 1.day.ago)
      expect(active_account.expired?).to be true

      active_account.update!(token_expires_at: 1.day.from_now)
      expect(active_account.expired?).to be false

      active_account.update!(token_expires_at: nil)
      expect(active_account.expired?).to be false
    end

    it '#platform_name returns readable platform name' do
      expect(active_account.platform_name).to eq('Facebook')
    end
  end
end

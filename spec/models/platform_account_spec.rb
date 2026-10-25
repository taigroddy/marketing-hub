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
      expect(fb_account).to be_a(described_class)
      expect(fb_account).to be_a(PlatformAccount::Facebook)
      expect(fb_account.type).to eq('PlatformAccount::Facebook')
    end

    it 'allows instantiating PlatformAccount::Google subclass' do
      google_account = PlatformAccount::Google.new(valid_attributes.except(:type).merge(account_id: 'goog_987654'))
      expect(google_account).to be_a(described_class)
      expect(google_account).to be_a(PlatformAccount::Google)
      expect(google_account.type).to eq('PlatformAccount::Google')
    end
  end

  describe 'associations' do
    it 'belongs to a user' do
      account = described_class.new(valid_attributes)
      expect(account.user).to eq(user)
    end

    it 'has many platform_campaigns with dependent destroy' do
      assoc = described_class.reflect_on_association(:platform_campaigns)
      expect(assoc.macro).to eq(:has_many)
      expect(assoc.options[:dependent]).to eq(:destroy)
    end

    it 'has many campaigns through platform_campaigns' do
      assoc = described_class.reflect_on_association(:campaigns)
      expect(assoc.macro).to eq(:has_many)
      expect(assoc.options[:through]).to eq(:platform_campaigns)
    end
  end

  describe 'database constraints' do
    it 'raises ActiveRecord::NotNullViolation when type is null' do
      expect do
        described_class.create!(valid_attributes.merge(type: nil))
      end.to raise_error(ActiveRecord::NotNullViolation)
    end

    it 'raises ActiveRecord::NotNullViolation when account_id is null' do
      expect do
        described_class.create!(valid_attributes.merge(account_id: nil))
      end.to raise_error(ActiveRecord::NotNullViolation)
    end

    it 'raises ActiveRecord::NotNullViolation when access_token is null' do
      expect do
        described_class.create!(valid_attributes.merge(access_token: nil))
      end.to raise_error(ActiveRecord::NotNullViolation)
    end

    it 'raises ActiveRecord::RecordNotUnique on duplicate (user_id, type, account_id)' do
      described_class.create!(valid_attributes)
      expect do
        described_class.create!(valid_attributes)
      end.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it 'allows same account_id for different users' do
      other_user = User.create!(
        email: 'other-user@example.com',
        password: 'Password123!',
        confirmed_at: Time.current
      )
      described_class.create!(valid_attributes)
      account_other = described_class.create!(valid_attributes.merge(user: other_user))
      expect(account_other).to be_persisted
    end

    it 'allows same account_id for different platform types' do
      described_class.create!(valid_attributes)
      google_account = PlatformAccount::Google.create!(valid_attributes.except(:type))
      expect(google_account).to be_persisted
    end
  end

  describe 'database defaults' do
    it 'defaults status to connected' do
      account = described_class.create!(valid_attributes.except(:status))
      expect(account.status).to eq('connected')
    end
  end

  describe 'token encryption (ActiveRecord::Encryption)' do
    before { Current.user = user }
    after { Current.reset }

    it 'encrypts access_token and refresh_token in database while returning plaintext in model' do
      raw_access_token = 'EAABsb7819238912389_super_secret_token'
      raw_refresh_token = 'REFRESH_TOKEN_998877_super_secret'

      account = described_class.create!(
        valid_attributes.merge(
          access_token: raw_access_token,
          refresh_token: raw_refresh_token
        )
      )

      reloaded = described_class.find(account.id)
      expect(reloaded.access_token).to eq(raw_access_token)
      expect(reloaded.refresh_token).to eq(raw_refresh_token)

      raw_sql = "SELECT access_token, refresh_token FROM platform_accounts WHERE id = #{account.id}"
      raw_row = ActiveRecord::Base.connection.select_one(raw_sql)

      expect(raw_row['access_token']).not_to eq(raw_access_token)
      expect(raw_row['access_token']).not_to include(raw_access_token)
      expect(raw_row['refresh_token']).not_to eq(raw_refresh_token)
      expect(raw_row['refresh_token']).not_to include(raw_refresh_token)
    end
  end

  describe 'methods and scopes' do
    before { Current.user = user }
    after { Current.reset }

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

    it 'destroys dependent platform_campaigns when account is destroyed' do
      campaign = Campaign.create!(
        user: user,
        name: 'Cascade Campaign',
        objective: 'OUTCOME_LEADS',
        budget: 500.0
      )
      PlatformCampaign.create!(
        campaign: campaign,
        platform_account: active_account,
        sync_status: 'pending'
      )

      expect { active_account.destroy }.to change(PlatformCampaign, :count).by(-1)
    end
  end

  describe 'multi-tenant default_scope' do
    let(:other_user) do
      User.create!(
        email: 'other-platform-scope-user@example.com',
        password: 'Password123!',
        confirmed_at: Time.current
      )
    end

    let!(:user_account) do
      described_class.create!(valid_attributes)
    end

    let!(:other_account) do
      described_class.create!(
        valid_attributes.merge(
          user: other_user,
          account_id: 'act_other_tenant_123',
          name: 'Other User Account'
        )
      )
    end

    after do
      Current.reset
    end

    context 'when Current.user is set' do
      before do
        Current.user = user
      end

      it 'automatically filters .all to only records belonging to Current.user' do
        expect(described_class.all).to include(user_account)
        expect(described_class.all).not_to include(other_account)
      end

      it 'bypasses the user filter when using .unscoped' do
        expect(described_class.unscoped.all).to include(user_account, other_account)
      end
    end

    context 'when Current.user is nil' do
      before do
        Current.user = nil
      end

      it 'returns no records by default to prevent data leakage' do
        expect(described_class.all).to be_empty
      end

      it 'returns all records when explicitly using .unscoped' do
        expect(described_class.unscoped.all).to include(user_account, other_account)
      end
    end
  end
end

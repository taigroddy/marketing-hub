# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Campaign, type: :model do
  let(:user) do
    User.create!(
      email: 'campaign-owner@example.com',
      password: 'Password123!',
      confirmed_at: Time.current
    )
  end

  subject(:campaign) do
    described_class.new(
      user: user,
      name: 'Summer Sale 2026',
      objective: 'OUTCOME_TRAFFIC',
      budget: 1500.50,
      status: 'draft'
    )
  end

  describe 'associations' do
    it 'belongs to user' do
      expect(campaign.user).to eq(user)
    end

    it 'has many platform_campaigns with dependent destroy' do
      assoc = described_class.reflect_on_association(:platform_campaigns)
      expect(assoc.macro).to eq(:has_many)
      expect(assoc.options[:dependent]).to eq(:destroy)
    end

    it 'has many platform_accounts through platform_campaigns' do
      assoc = described_class.reflect_on_association(:platform_accounts)
      expect(assoc.macro).to eq(:has_many)
      expect(assoc.options[:through]).to eq(:platform_campaigns)
    end
  end

  describe 'database constraints' do
    it 'raises ActiveRecord::NotNullViolation when name is null' do
      expect do
        described_class.create!(
          user: user,
          name: nil,
          objective: 'OUTCOME_LEADS',
          budget: 100.0
        )
      end.to raise_error(ActiveRecord::NotNullViolation)
    end

    it 'raises ActiveRecord::NotNullViolation when objective is null' do
      expect do
        described_class.create!(
          user: user,
          name: 'Promo',
          objective: nil,
          budget: 100.0
        )
      end.to raise_error(ActiveRecord::NotNullViolation)
    end

    it 'raises ActiveRecord::NotNullViolation when budget is null' do
      expect do
        described_class.create!(
          user: user,
          name: 'Promo',
          objective: 'OUTCOME_LEADS',
          budget: nil
        )
      end.to raise_error(ActiveRecord::NotNullViolation)
    end
  end

  describe 'database defaults' do
    it 'defaults status to draft' do
      new_campaign = described_class.create!(
        user: user,
        name: 'Promo',
        objective: 'OUTCOME_LEADS',
        budget: 100.0
      )
      expect(new_campaign.status).to eq('draft')
    end
  end

  describe 'dependent destroy' do
    it 'destroys dependent platform_campaigns when campaign is destroyed' do
      campaign.save!
      account = PlatformAccount::Facebook.create!(
        user: user,
        account_id: 'act_camp_cascade',
        name: 'FB',
        access_token: 'secret_token_123',
        status: 'connected'
      )
      PlatformCampaign.create!(
        campaign: campaign,
        platform_account: account,
        sync_status: 'pending'
      )

      expect { campaign.destroy }.to change(PlatformCampaign, :count).by(-1)
    end
  end

  describe 'zero callback job triggers' do
    it 'does not enqueue any background jobs on save' do
      expect do
        campaign.save!
      end.not_to have_enqueued_job
    end
  end

  describe 'multi-tenant default_scope' do
    let(:other_user) do
      User.create!(
        email: 'other-user-scope@example.com',
        password: 'Password123!',
        confirmed_at: Time.current
      )
    end

    let!(:user_campaign) do
      described_class.create!(
        user: user,
        name: 'User 1 Campaign',
        objective: 'OUTCOME_TRAFFIC',
        budget: 500.0,
        status: 'draft'
      )
    end

    let!(:other_campaign) do
      described_class.create!(
        user: other_user,
        name: 'User 2 Campaign',
        objective: 'OUTCOME_LEADS',
        budget: 800.0,
        status: 'draft'
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
        expect(described_class.all).to include(user_campaign)
        expect(described_class.all).not_to include(other_campaign)
      end

      it 'bypasses the user filter when using .unscoped' do
        expect(described_class.unscoped.all).to include(user_campaign, other_campaign)
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
        expect(described_class.unscoped.all).to include(user_campaign, other_campaign)
      end
    end
  end
end

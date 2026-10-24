# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PlatformCampaign, type: :model do
  let(:user) do
    User.create!(
      email: 'platform_camp_user@example.com',
      password: 'Password123!',
      confirmed_at: Time.current
    )
  end

  let(:campaign) do
    Campaign.create!(
      user: user,
      name: 'Spring Sale 2026',
      objective: 'OUTCOME_SALES',
      budget: 1000.0,
      status: 'active'
    )
  end

  let(:platform_account) do
    PlatformAccount::Facebook.create!(
      user: user,
      account_id: 'act_123456789',
      name: 'FB Main Account',
      access_token: 'eaab_fake_token',
      status: 'connected'
    )
  end

  subject(:platform_campaign) do
    described_class.new(
      campaign: campaign,
      platform_account: platform_account,
      sync_status: 'pending'
    )
  end

  describe 'associations' do
    it 'belongs to campaign and platform_account' do
      expect(platform_campaign.campaign).to eq(campaign)
      expect(platform_campaign.platform_account).to eq(platform_account)
    end

    it 'adds has_many :platform_campaigns to Campaign' do
      expect(campaign).to respond_to(:platform_campaigns)
      expect(campaign).to respond_to(:platform_accounts)
    end

    it 'adds has_many :platform_campaigns to PlatformAccount' do
      expect(platform_account).to respond_to(:platform_campaigns)
      expect(platform_account).to respond_to(:campaigns)
    end
  end

  describe 'database constraints' do
    it 'raises ActiveRecord::RecordNotUnique on duplicate (campaign_id, platform_account_id)' do
      platform_campaign.save!
      expect do
        described_class.create!(
          campaign: campaign,
          platform_account: platform_account,
          sync_status: 'pending'
        )
      end.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end

  describe 'database defaults' do
    it 'defaults sync_status to pending' do
      record = described_class.create!(
        campaign: campaign,
        platform_account: platform_account
      )
      expect(record.sync_status).to eq('pending')
    end
  end

  describe '#out_of_sync? / #drifted?' do
    before { platform_campaign.save! }

    context 'when synced_at is nil' do
      it 'returns false' do
        platform_campaign.update_columns(synced_at: nil)
        expect(platform_campaign.out_of_sync?).to be false
        expect(platform_campaign.drifted?).to be false
      end
    end

    context 'when campaign was updated after synced_at (drift detected)' do
      it 'returns true' do
        platform_campaign.update_columns(synced_at: 10.minutes.ago)
        campaign.update_columns(updated_at: 2.minutes.ago)

        expect(platform_campaign.out_of_sync?).to be true
        expect(platform_campaign.drifted?).to be true
      end
    end

    context 'when campaign was not updated after synced_at' do
      it 'returns false' do
        campaign.update_columns(updated_at: 10.minutes.ago)
        platform_campaign.update_columns(synced_at: 2.minutes.ago)

        expect(platform_campaign.out_of_sync?).to be false
        expect(platform_campaign.drifted?).to be false
      end
    end
  end
end

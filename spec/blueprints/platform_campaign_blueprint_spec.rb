# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PlatformCampaignBlueprint do
  let(:user) do
    User.create!(
      email: 'bp_platform_user@example.com',
      password: 'Password123!',
      confirmed_at: Time.current
    )
  end

  let(:campaign) do
    Campaign.create!(
      user: user,
      name: 'Blueprint Test Camp',
      objective: 'OUTCOME_LEADS',
      budget: 1200.0,
      status: 'active'
    )
  end

  let(:platform_account) do
    PlatformAccount::Facebook.create!(
      user: user,
      account_id: 'act_bp_123',
      name: 'BP Facebook Account',
      access_token: 'fake_tok',
      status: 'connected'
    )
  end

  let(:platform_campaign) do
    PlatformCampaign.create!(
      campaign: campaign,
      platform_account: platform_account,
      external_campaign_id: 'fb_bp_cam_99',
      sync_status: 'synced',
      synced_at: 1.hour.from_now
    )
  end

  describe '.render_as_hash' do
    it 'serializes platform campaign attributes and out_of_sync status' do
      hash = described_class.render_as_hash(platform_campaign)

      expect(hash).to include(
        id: platform_campaign.id,
        campaign_id: campaign.id,
        platform_account_id: platform_account.id,
        external_campaign_id: 'fb_bp_cam_99',
        sync_status: 'synced',
        out_of_sync: false
      )

      platform_campaign.update_columns(synced_at: 2.hours.ago)
      campaign.update_columns(updated_at: 10.minutes.ago)
      drifted_hash = described_class.render_as_hash(platform_campaign)
      expect(drifted_hash[:out_of_sync]).to be true
    end
  end
end

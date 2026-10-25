# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PlatformCampaigns::ResyncService, type: :service do
  include ActiveJob::TestHelper

  let(:user) do
    User.create!(
      email: 'resync_service_user@example.com',
      password: 'Password123!',
      confirmed_at: Time.current
    )
  end

  let(:campaign) do
    Campaign.create!(
      user: user,
      name: 'Autumn Clearance',
      objective: 'OUTCOME_ENGAGEMENT',
      budget: 800.0,
      status: 'active'
    )
  end

  let(:platform_account) do
    PlatformAccount::Facebook.create!(
      user: user,
      account_id: 'act_fb_888',
      name: 'FB Store Autumn',
      access_token: 'token_888',
      status: 'connected'
    )
  end

  let!(:platform_campaign) do
    PlatformCampaign.create!(
      campaign: campaign,
      platform_account: platform_account,
      external_campaign_id: 'fb_ext_888',
      sync_status: 'synced',
      synced_at: 1.hour.ago
    )
  end

  before do
    Current.user = user
  end

  after do
    Current.user = nil
  end

  describe 'validations' do
    it 'fails validation when campaign id is missing' do
      result = described_class.call(platform: 'facebook', platform_campaign_id: platform_campaign.id)
      expect(result).to be_failure
      expect(result.failure[:id]).to be_present
    end

    it 'fails validation when platform_campaign_id is missing' do
      result = described_class.call(id: campaign.id, platform: 'facebook')
      expect(result).to be_failure
      expect(result.failure[:platform_campaign_id]).to be_present
    end

    it 'matches block matcher m.failure(:validation) when validation fails' do
      validation_triggered = false
      described_class.call(platform: 'facebook') do |m|
        m.success { |_r| }
        m.failure(:validation) { |_e| validation_triggered = true }
        m.failure { |_e| }
      end

      expect(validation_triggered).to be true
    end
  end

  describe 'detect drift via synced_at' do
    context 'when NO drift exists (campaign was not updated after synced_at)' do
      before do
        campaign.update_columns(updated_at: 2.hours.ago)
        platform_campaign.update_columns(synced_at: 1.hour.ago)
      end

      it 'returns failure indicating no drift detected' do
        expect do
          result = described_class.call(
            id: campaign.id,
            platform: 'facebook',
            platform_campaign_id: platform_campaign.id
          )
          expect(result).to be_failure
          expect(result.failure[:error]).to include('No drift detected')
        end.not_to have_enqueued_job(SyncCampaignJob)
      end

      it 'allows force resync when force: true' do
        expect do
          result = described_class.call(
            id: campaign.id,
            platform: 'facebook',
            platform_campaign_id: platform_campaign.id,
            force: true
          )
          expect(result).to be_success
        end.to have_enqueued_job(SyncCampaignJob).with(platform_campaign.id)
      end
    end

    context 'when DRIFT IS DETECTED (campaign.updated_at > platform_campaign.synced_at)' do
      before do
        platform_campaign.update_columns(synced_at: 2.hours.ago)
        campaign.update_columns(updated_at: 10.minutes.ago)
      end

      it 'detects drift, updates status to pending via mark_pending, and enqueues SyncCampaignJob via enqueue_sync_job' do
        expect do
          result = described_class.call(
            id: campaign.id,
            platform: 'facebook',
            platform_campaign_id: platform_campaign.id
          )
          expect(result).to be_success
          expect(result.value![:platform_campaigns].first.id).to eq(platform_campaign.id)
        end.to have_enqueued_job(SyncCampaignJob).with(platform_campaign.id)

        platform_campaign.reload
        expect(platform_campaign.sync_status).to eq('pending')
      end

      it 'supports targeting a specific platform_campaign_id' do
        expect do
          result = described_class.call(
            id: campaign.id,
            platform: 'facebook',
            platform_campaign_id: platform_campaign.id
          )

          expect(result).to be_success
        end.to have_enqueued_job(SyncCampaignJob).with(platform_campaign.id)
      end

      it 'supports synchronous mode (async: false) executing outside DB transactions', vcr: { cassette_name: 'facebook_sync_campaign', record: :new_episodes } do
        resync_campaign = Campaign.create!(
          user: user,
          name: 'Summer Promo 2026 Updated',
          objective: 'OUTCOME_TRAFFIC',
          budget: 150_000.0,
          status: 'active',
          updated_at: Time.current
        )
        resync_account = PlatformAccount::Facebook.create!(
          user: user,
          account_id: '2183515115230038',
          name: 'FB Store Resync',
          access_token: ENV['FB_TEST_ACCESS_TOKEN'].presence || '<FB_TEST_ACCESS_TOKEN>',
          status: 'connected'
        )
        resync_pc = PlatformCampaign.create!(
          campaign: resync_campaign,
          platform_account: resync_account,
          external_campaign_id: '120252471634210228',
          sync_status: 'synced',
          synced_at: 1.day.ago
        )

        result = described_class.call(
          id: resync_campaign.id,
          platform: 'facebook',
          platform_campaign_id: resync_pc.id,
          async: false
        )

        expect(result).to be_success
        resync_pc.reload
        expect(resync_pc.sync_status).to eq('synced')
        expect(resync_pc.synced_at).to be_within(10.seconds).of(Time.current)
      end
    end
  end

  describe 'resource checks' do
    it 'fails when campaign does not belong to user' do
      other_user = User.create!(
        email: 'other_resync@example.com',
        password: 'Password123!',
        confirmed_at: Time.current
      )
      other_camp = Campaign.create!(
        user: other_user,
        name: 'Other Camp',
        objective: 'OUTCOME_LEADS',
        budget: 100.0,
        status: 'draft'
      )

      result = described_class.call(
        id: other_camp.id,
        platform: 'facebook',
        platform_campaign_id: platform_campaign.id
      )
      expect(result).to be_failure
      expect(result.failure[:campaign]).to include('not found')
    end

    it 'fails when no platform campaign exists for this campaign' do
      platform_campaign.destroy!

      result = described_class.call(
        id: campaign.id,
        platform: 'facebook',
        platform_campaign_id: 999_999
      )
      expect(result).to be_failure
      expect(result.failure[:platform_campaigns]).to include('not found')
    end
  end
end

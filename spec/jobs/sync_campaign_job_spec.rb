# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SyncCampaignJob, type: :job do
  include ActiveJob::TestHelper

  let(:user) do
    User.create!(
      email: 'sync_job_test_user@example.com',
      password: 'Password123!',
      confirmed_at: Time.current
    )
  end

  let(:campaign) do
    Campaign.create!(
      user: user,
      name: 'Summer Promo 2026',
      objective: 'OUTCOME_TRAFFIC',
      budget: 100_000.0,
      status: 'active'
    )
  end

  let(:fb_token) { ENV['FB_TEST_ACCESS_TOKEN'].presence || '<FB_TEST_ACCESS_TOKEN>' }
  let(:fb_account_id) { '2183515115230038' }

  let(:facebook_account) do
    PlatformAccount::Facebook.create!(
      user: user,
      account_id: fb_account_id,
      name: 'Facebook Test Account',
      access_token: fb_token,
      status: 'connected'
    )
  end

  let(:platform_campaign) do
    PlatformCampaign.create!(
      campaign: campaign,
      platform_account: facebook_account,
      sync_status: 'pending'
    )
  end

  describe '#perform' do
    it 'enqueues job in the default queue' do
      expect do
        described_class.perform_later(platform_campaign.id)
      end.to have_enqueued_job(described_class).with(platform_campaign.id).on_queue('default')
    end

    it 'executes enqueued job with real records delegating to SyncService', vcr: { cassette_name: 'facebook_sync_campaign', record: :new_episodes } do
      perform_enqueued_jobs do
        described_class.perform_later(platform_campaign.id)
      end

      platform_campaign.reload
      expect(platform_campaign.sync_status).to eq('synced')
      expect(platform_campaign.external_campaign_id).to be_present
      expect(platform_campaign.synced_at).to be_present
      expect(platform_campaign.last_error_message).to be_nil
    end

    it 'handles missing platform_campaign gracefully without raising' do
      expect do
        perform_enqueued_jobs do
          described_class.perform_later(999_999)
        end
      end.not_to raise_error
    end

    context 'with google platform account' do
      let(:google_account) do
        PlatformAccount::Google.create!(
          user: user,
          account_id: 'act_google_555',
          name: 'Google Test Account',
          access_token: 'google_tok',
          status: 'connected'
        )
      end

      let(:google_platform_campaign) do
        PlatformCampaign.create!(
          campaign: campaign,
          platform_account: google_account,
          sync_status: 'pending'
        )
      end

      it 'executes and persists failure status via SyncService' do
        perform_enqueued_jobs do
          described_class.perform_later(google_platform_campaign.id)
        end

        google_platform_campaign.reload
        expect(google_platform_campaign.sync_status).to eq('failed')
        expect(google_platform_campaign.last_error_message).to include('Google platform integration coming soon')
      end
    end
  end
end

# frozen_string_literal: true

require 'rails_helper'

class PlatformAccount::Tiktok < PlatformAccount
end

RSpec.describe PlatformCampaigns::SyncService, type: :service do
  let(:user) do
    User.create!(
      email: 'sync_service_user@example.com',
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

  describe '#check_resource' do
    context 'when platform_campaign does not exist' do
      it 'returns failure' do
        result = described_class.call(platform_campaign_id: 999_999)
        expect(result).to be_failure
        expect(result.failure[:platform_campaign]).to include('not found')
      end
    end
  end

  describe '#call_platform_api and platform routing' do
    context 'CRITICAL DIRECTIVE: DB Transaction check' do
      it 'prevents execution inside ActiveRecord::Base.transaction and persists failure' do
        ActiveRecord::Base.transaction do
          described_class.call(platform_campaign_id: platform_campaign.id)
        end

        platform_campaign.reload
        expect(platform_campaign.sync_status).to eq('failed')
        expect(platform_campaign.last_error_message).to include('Violation: 3rd party API called inside DB transaction')
      end
    end

    context 'when platform is google' do
      let(:google_account) do
        PlatformAccount::Google.create!(
          user: user,
          account_id: 'google_act_123',
          name: 'Google Ads Account',
          access_token: 'google_token',
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

      it 'persists failed status with unsupported platform error and broadcasts' do
        expect do
          result = described_class.call(platform_campaign_id: google_platform_campaign.id)
          expect(result).to be_failure
          expect(result.failure[:error]).to include('Google platform integration coming soon')
        end.to change {
          ActionCable.server.pubsub.broadcasts("campaign_#{campaign.id}").size
        }.by(2)

        google_platform_campaign.reload
        expect(google_platform_campaign.sync_status).to eq('failed')
        expect(google_platform_campaign.last_error_message).to include('Google platform integration coming soon')
      end
    end

    context 'when platform is unsupported' do
      let(:tiktok_account) do
        PlatformAccount::Tiktok.create!(
          user: user,
          account_id: 'tiktok_act_123',
          name: 'TikTok Ads Account',
          access_token: 'tiktok_token',
          status: 'connected'
        )
      end

      let(:tiktok_platform_campaign) do
        PlatformCampaign.create!(
          campaign: campaign,
          platform_account: tiktok_account,
          sync_status: 'pending'
        )
      end

      it 'persists failed status with unsupported platform message and broadcasts' do
        result = described_class.call(platform_campaign_id: tiktok_platform_campaign.id)
        expect(result).to be_failure
        expect(result.failure[:error]).to include('Unsupported platform: tiktok')

        tiktok_platform_campaign.reload
        expect(tiktok_platform_campaign.sync_status).to eq('failed')
        expect(tiktok_platform_campaign.last_error_message).to include('Unsupported platform: tiktok')
      end
    end

    context 'when unexpected exception is raised during API call' do
      let(:invalid_account) do
        PlatformAccount::Facebook.create!(
          user: user,
          account_id: '',
          name: 'Invalid Account',
          access_token: fb_token,
          status: 'connected'
        )
      end

      let(:invalid_platform_campaign) do
        PlatformCampaign.create!(
          campaign: campaign,
          platform_account: invalid_account,
          sync_status: 'pending'
        )
      end

      it 'catches exception, persists error result, and broadcasts' do
        expect do
          result = described_class.call(platform_campaign_id: invalid_platform_campaign.id)
          expect(result).to be_failure
          expect(result.failure[:error]).to include('Missing required account_id')
        end.to change {
          ActionCable.server.pubsub.broadcasts("campaign_#{campaign.id}").size
        }.by(2)

        invalid_platform_campaign.reload
        expect(invalid_platform_campaign.sync_status).to eq('failed')
        expect(invalid_platform_campaign.last_error_message).to include('Missing required account_id')
      end
    end
  end

  describe 'Facebook API sync with real VCR cassette', vcr: { cassette_name: 'facebook_sync_campaign', record: :new_episodes } do
    context 'when creating a new external campaign (external_campaign_id is blank)' do
      it 'creates campaign, persists synced status, and broadcasts turbo stream updates' do
        messages_before = ActionCable.server.pubsub.broadcasts("campaign_#{campaign.id}").size

        result = described_class.call(platform_campaign_id: platform_campaign.id)

        expect(result).to be_success
        platform_campaign.reload
        expect(platform_campaign.sync_status).to eq('synced')
        expect(platform_campaign.external_campaign_id).to be_present
        expect(platform_campaign.synced_at).to be_present
        expect(platform_campaign.last_error_message).to be_nil

        messages_after = ActionCable.server.pubsub.broadcasts("campaign_#{campaign.id}").size
        expect(messages_after - messages_before).to eq(2)
      end
    end

    context 'when re-syncing an existing external campaign (external_campaign_id is present)' do
      before do
        platform_campaign.update_columns(
          external_campaign_id: '120252471634210228',
          synced_at: 1.day.ago,
          sync_status: 'pending'
        )
        campaign.update!(budget: 150_000.0, name: 'Summer Promo 2026 Updated')
      end

      it 'updates campaign, updates synced_at, and broadcasts' do
        result = described_class.call(platform_campaign_id: platform_campaign.id)

        expect(result).to be_success
        platform_campaign.reload
        expect(platform_campaign.sync_status).to eq('synced')
        expect(platform_campaign.synced_at).to be_within(10.seconds).of(Time.current)
        expect(platform_campaign.last_error_message).to be_nil
      end
    end

    context 'when Facebook API returns an error' do
      before do
        platform_campaign.update_columns(
          external_campaign_id: 'invalid_campaign_id_99999',
          sync_status: 'pending'
        )
      end

      it 'marks record as failed with error message and broadcasts' do
        messages_before = ActionCable.server.pubsub.broadcasts("campaign_#{campaign.id}").size

        result = described_class.call(platform_campaign_id: platform_campaign.id)

        expect(result).to be_failure
        expect(result.failure[:error]).to include('Unsupported post request')

        platform_campaign.reload
        expect(platform_campaign.sync_status).to eq('failed')
        expect(platform_campaign.last_error_message).to include('Unsupported post request')

        messages_after = ActionCable.server.pubsub.broadcasts("campaign_#{campaign.id}").size
        expect(messages_after - messages_before).to eq(2)
      end
    end

    context 'block matcher syntax' do
      it 'yields to matcher blocks correctly' do
        success_called = false
        described_class.call(platform_campaign_id: platform_campaign.id) do |m|
          m.success { success_called = true }
          m.failure { raise 'should not fail' }
        end

        expect(success_called).to be true
      end
    end
  end
end

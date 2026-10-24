# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SyncCampaignJob, type: :job do
  let(:user) do
    User.create!(
      email: 'sync_job_user@example.com',
      password: 'Password123!',
      confirmed_at: Time.current
    )
  end

  let(:campaign) do
    Campaign.create!(
      user: user,
      name: 'Summer Promo',
      objective: 'OUTCOME_TRAFFIC',
      budget: 500.0,
      status: 'active'
    )
  end

  let(:platform_account) do
    PlatformAccount::Facebook.create!(
      user: user,
      account_id: 'act_fb_999999',
      name: 'Facebook Test Account',
      access_token: 'valid_fb_token',
      status: 'connected'
    )
  end

  let(:platform_campaign) do
    PlatformCampaign.create!(
      campaign: campaign,
      platform_account: platform_account,
      sync_status: 'pending'
    )
  end

  let(:mock_facebook_client) { instance_double(Clients::AdCampaign::FacebookClient) }

  before do
    allow(Clients::AdCampaign::FacebookClient).to receive(:new).and_return(mock_facebook_client)
  end

  describe '#perform' do
    context 'CRITICAL DIRECTIVE: DB Transaction check' do
      it 'guarantees calls to FacebookClient occur strictly OUTSIDE ActiveRecord::Base.transaction' do
        expect(mock_facebook_client).to receive(:create_campaign) do
          threshold = Rails.env.test? ? 1 : 0
          expect(ActiveRecord::Base.connection.open_transactions).to be <= threshold
          Dry::Monads::Success(id: 'fb_ext_12345')
        end

        described_class.perform_now(platform_campaign.id)
      end

      it 'prevents execution inside ActiveRecord::Base.transaction' do
        ActiveRecord::Base.transaction do
          described_class.perform_now(platform_campaign.id)
        end

        platform_campaign.reload
        expect(platform_campaign.sync_status).to eq('failed')
        expect(platform_campaign.last_error_message).to include('Violation: 3rd party API called inside DB transaction')
      end
    end

    context 'CRITICAL DIRECTIVE: Use upsert / upsert_all' do
      it 'uses ActiveRecord upsert or upsert_all to persist results' do
        allow(mock_facebook_client).to receive(:create_campaign).and_return(
          Dry::Monads::Success(id: 'fb_ext_12345')
        )

        expect(PlatformCampaign).to receive(:upsert).with(
          hash_including(
            id: platform_campaign.id,
            sync_status: 'synced',
            external_campaign_id: 'fb_ext_12345'
          ),
          unique_by: :id
        ).and_call_original

        described_class.perform_now(platform_campaign.id)
      end
    end

    context 'when creating a new external campaign (external_campaign_id is blank)' do
      it 'calls create_campaign on adapter and sets status to synced with external_campaign_id' do
        expect(mock_facebook_client).to receive(:create_campaign).with(
          name: campaign.name,
          objective: campaign.objective,
          budget: campaign.budget,
          account_id: platform_account.account_id
        ).and_return(Dry::Monads::Success(id: 'fb_new_cam_001'))

        described_class.perform_now(platform_campaign.id)

        platform_campaign.reload
        expect(platform_campaign.sync_status).to eq('synced')
        expect(platform_campaign.external_campaign_id).to eq('fb_new_cam_001')
        expect(platform_campaign.synced_at).to be_within(5.seconds).of(Time.current)
        expect(platform_campaign.last_error_message).to be_nil
      end
    end

    context 'when re-syncing an existing external campaign (external_campaign_id is present)' do
      before do
        platform_campaign.update_columns(
          external_campaign_id: 'fb_existing_111',
          synced_at: 1.day.ago,
          sync_status: 'pending'
        )
      end

      it 'calls update_campaign on adapter and updates synced_at' do
        expect(mock_facebook_client).to receive(:update_campaign).with(
          campaign_id: 'fb_existing_111',
          budget: campaign.budget,
          name: campaign.name
        ).and_return(Dry::Monads::Success(id: 'fb_existing_111'))

        described_class.perform_now(platform_campaign.id)

        platform_campaign.reload
        expect(platform_campaign.sync_status).to eq('synced')
        expect(platform_campaign.external_campaign_id).to eq('fb_existing_111')
        expect(platform_campaign.synced_at).to be_within(5.seconds).of(Time.current)
        expect(platform_campaign.last_error_message).to be_nil
      end
    end

    context 'when adapter call returns failure' do
      it 'sets sync_status to failed and updates last_error_message' do
        expect(mock_facebook_client).to receive(:create_campaign).and_return(
          Dry::Monads::Failure(error: 'Invalid campaign objective')
        )

        described_class.perform_now(platform_campaign.id)

        platform_campaign.reload
        expect(platform_campaign.sync_status).to eq('failed')
        expect(platform_campaign.last_error_message).to eq('Invalid campaign objective')
      end
    end

    context 'when adapter raises an unexpected exception' do
      it 'handles exception gracefully, marking status as failed' do
        expect(mock_facebook_client).to receive(:create_campaign).and_raise(
          Net::OpenTimeout, 'Connection timed out'
        )

        described_class.perform_now(platform_campaign.id)

        platform_campaign.reload
        expect(platform_campaign.sync_status).to eq('failed')
        expect(platform_campaign.last_error_message).to include('Connection timed out')
      end
    end

    context 'when platform_campaign does not exist' do
      it 'does not raise error' do
        expect { described_class.perform_now(999_999) }.not_to raise_error
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

      it 'sets status to failed with not supported error' do
        described_class.perform_now(google_platform_campaign.id)

        google_platform_campaign.reload
        expect(google_platform_campaign.sync_status).to eq('failed')
        expect(google_platform_campaign.last_error_message).to include('Google platform integration coming soon')
      end
    end

    context 'Turbo Stream broadcasts' do
      before do
        allow(mock_facebook_client).to receive(:create_campaign).and_return(
          Dry::Monads::Success(id: 'fb_ext_12345')
        )
      end

      it 'broadcasts replacement for platform_accounts_section and platform_campaigns_section on success' do
        expect(Turbo::StreamsChannel).to receive(:broadcast_replace_to).with(
          "campaign_#{campaign.id}",
          target: 'platform_accounts_section',
          partial: 'campaigns/platform_accounts_section',
          locals: {
            campaign: campaign,
            platform_accounts: campaign.user.platform_accounts,
            platform_campaigns: campaign.platform_campaigns
          }
        )

        expect(Turbo::StreamsChannel).to receive(:broadcast_replace_to).with(
          "campaign_#{campaign.id}",
          target: 'platform_campaigns_section',
          partial: 'campaigns/platform_campaigns_section',
          locals: {
            campaign: campaign,
            platform_campaigns: campaign.platform_campaigns
          }
        )

        described_class.perform_now(platform_campaign.id)
      end

      it 'broadcasts replacement when adapter returns failure' do
        allow(mock_facebook_client).to receive(:create_campaign).and_return(
          Dry::Monads::Failure(error: 'API rate limit')
        )

        expect(Turbo::StreamsChannel).to receive(:broadcast_replace_to).with(
          "campaign_#{campaign.id}",
          target: 'platform_accounts_section',
          partial: 'campaigns/platform_accounts_section',
          locals: hash_including(campaign: an_instance_of(Campaign))
        )

        expect(Turbo::StreamsChannel).to receive(:broadcast_replace_to).with(
          "campaign_#{campaign.id}",
          target: 'platform_campaigns_section',
          partial: 'campaigns/platform_campaigns_section',
          locals: hash_including(campaign: an_instance_of(Campaign))
        )

        described_class.perform_now(platform_campaign.id)
      end

      it 'broadcasts replacement when an unexpected error is raised' do
        allow(mock_facebook_client).to receive(:create_campaign).and_raise(
          Net::OpenTimeout, 'Connection timed out'
        )

        expect(Turbo::StreamsChannel).to receive(:broadcast_replace_to).with(
          "campaign_#{campaign.id}",
          target: 'platform_accounts_section',
          partial: 'campaigns/platform_accounts_section',
          locals: hash_including(campaign: an_instance_of(Campaign))
        )

        expect(Turbo::StreamsChannel).to receive(:broadcast_replace_to).with(
          "campaign_#{campaign.id}",
          target: 'platform_campaigns_section',
          partial: 'campaigns/platform_campaigns_section',
          locals: hash_including(campaign: an_instance_of(Campaign))
        )

        described_class.perform_now(platform_campaign.id)
      end

      it 'does not broadcast when platform_campaign is not found' do
        expect(Turbo::StreamsChannel).not_to receive(:broadcast_replace_to)

        described_class.perform_now(999_999)
      end

      it 'renders both partials and publishes turbo stream messages to ActionCable stream' do
        expect do
          described_class.perform_now(platform_campaign.id)
        end.to change {
          ActionCable.server.pubsub.broadcasts("campaign_#{campaign.id}").size
        }.by(2)

        messages = ActionCable.server.pubsub.broadcasts("campaign_#{campaign.id}")
        expect(messages[0]).to include('target=\"platform_accounts_section\"')
        expect(messages[1]).to include('target=\"platform_campaigns_section\"')
      end
    end
  end
end

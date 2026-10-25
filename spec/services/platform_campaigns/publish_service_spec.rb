# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PlatformCampaigns::PublishService, type: :service do
  include ActiveJob::TestHelper

  let(:user) do
    User.create!(
      email: 'publish_service_user@example.com',
      password: 'Password123!',
      confirmed_at: Time.current
    )
  end

  let(:campaign) do
    Campaign.create!(
      user: user,
      name: 'Black Friday Deals',
      objective: 'OUTCOME_SALES',
      budget: 2500.0,
      status: 'active'
    )
  end

  let(:account_fb1) do
    PlatformAccount::Facebook.create!(
      user: user,
      account_id: 'act_fb_111',
      name: 'FB Store 1',
      access_token: 'token_111',
      status: 'connected'
    )
  end

  let(:account_fb2) do
    PlatformAccount::Facebook.create!(
      user: user,
      account_id: 'act_fb_222',
      name: 'FB Store 2',
      access_token: 'token_222',
      status: 'connected'
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
      result = described_class.call(platform: 'facebook', platform_account_ids: [ account_fb1.id ])
      expect(result).to be_failure
      expect(result.failure[:campaign_id]).to be_present
    end

    it 'fails validation when platform_account_ids is empty' do
      result = described_class.call(
        id: campaign.id,
        platform: 'facebook',
        platform_account_ids: []
      )
      expect(result).to be_failure
      expect(result.failure[:platform_account_ids]).to be_present
    end

    it 'matches block matcher m.failure(:validation) when validation fails' do
      validation_triggered = false
      described_class.call(id: campaign.id, platform: 'facebook', platform_account_ids: []) do |m|
        m.success { |_r| }
        m.failure(:validation) { |_e| validation_triggered = true }
        m.failure { |_e| }
      end

      expect(validation_triggered).to be true
    end
  end

  describe 'resource checks' do
    it 'fails when user is not authenticated' do
      Current.user = nil
      result = described_class.call(
        id: campaign.id,
        platform: 'facebook',
        platform_account_ids: [ account_fb1.id ]
      )
      expect(result).to be_failure
      expect(result.failure).to eq(:unauthorized)
    end

    it 'fails when campaign belongs to another user' do
      other_user = User.create!(
        email: 'other_user@example.com',
        password: 'Password123!',
        confirmed_at: Time.current
      )
      other_campaign = Campaign.create!(
        user: other_user,
        name: 'Other Camp',
        objective: 'OUTCOME_AWARENESS',
        budget: 50.0,
        status: 'draft'
      )

      result = described_class.call(
        id: other_campaign.id,
        platform: 'facebook',
        platform_account_ids: [ account_fb1.id ]
      )
      expect(result).to be_failure
      expect(result.failure[:campaign]).to include('not found')
    end

    it 'fails when platform accounts do not belong to user or match platform' do
      other_user = User.create!(
        email: 'other_fb_user@example.com',
        password: 'Password123!',
        confirmed_at: Time.current
      )
      other_account = PlatformAccount::Facebook.create!(
        user: other_user,
        account_id: 'act_other_999',
        name: 'Other Account',
        access_token: 'tok_other',
        status: 'connected'
      )

      result = described_class.call(
        id: campaign.id,
        platform: 'facebook',
        platform_account_ids: [ other_account.id ]
      )
      expect(result).to be_failure
      expect(result.failure[:platform_accounts]).to include('invalid or not found')
    end

    it 'fails when Google platform is requested' do
      result = described_class.call(
        id: campaign.id,
        platform: 'google',
        platform_account_ids: [ account_fb1.id ]
      )
      expect(result).to be_failure
      expect(result.failure[:error]).to include('Google platform integration coming soon')
    end

    it 'fails validation if an account has already been published for this campaign' do
      PlatformCampaign.create!(
        campaign: campaign,
        platform_account: account_fb1,
        sync_status: 'synced',
        external_campaign_id: 'fb_existing_111'
      )

      result = described_class.call(
        id: campaign.id,
        platform: 'facebook',
        platform_account_ids: [ account_fb1.id, account_fb2.id ]
      )
      expect(result).to be_failure
      expect(result.failure[:platform_account_ids]).to include('already published for this campaign')
    end
  end

  describe 'process & execution' do
    it 'creates pending records via upsert_records and enqueues SyncCampaignJob via enqueue_sync_jobs' do
      expect do
        result = described_class.call(
          id: campaign.id,
          platform: 'facebook',
          platform_account_ids: [ account_fb1.id, account_fb2.id ]
        )
        expect(result).to be_success
        expect(result.value![:platform_campaigns].count).to eq(2)
      end.to change(PlatformCampaign, :count).by(2)
        .and have_enqueued_job(SyncCampaignJob).twice

      records = PlatformCampaign.where(campaign: campaign)
      expect(records.pluck(:sync_status).uniq).to eq([ 'pending' ])
    end

    it 'supports synchronous mode (async: false) executing outside DB transactions', vcr: { cassette_name: 'facebook_sync_campaign', record: :new_episodes } do
      sync_campaign = Campaign.create!(
        user: user,
        name: 'Summer Promo 2026',
        objective: 'OUTCOME_TRAFFIC',
        budget: 100_000.0,
        status: 'active'
      )
      sync_account = PlatformAccount::Facebook.create!(
        user: user,
        account_id: '2183515115230038',
        name: 'FB Store Sync',
        access_token: ENV['FB_TEST_ACCESS_TOKEN'].presence || '<FB_TEST_ACCESS_TOKEN>',
        status: 'connected'
      )

      result = described_class.call(
        id: sync_campaign.id,
        platform: 'facebook',
        platform_account_ids: [ sync_account.id ],
        async: false
      )

      expect(result).to be_success
      created_record = PlatformCampaign.find_by(campaign: sync_campaign, platform_account: sync_account)
      expect(created_record.sync_status).to eq('synced')
      expect(created_record.external_campaign_id).to eq('120252471690050228')
    end

    it 'matches block matcher m.success' do
      success_result = nil
      described_class.call(
        id: campaign.id,
        platform: 'facebook',
        platform_account_ids: [ account_fb1.id ]
      ) do |m|
        m.success { |r| success_result = r }
        m.failure(:validation) { |_e| }
        m.failure { |_e| }
      end

      expect(success_result).to be_present
      expect(success_result[:campaign]).to eq(campaign)
    end
  end
end

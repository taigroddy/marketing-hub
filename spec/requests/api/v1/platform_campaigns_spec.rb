# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::PlatformCampaigns', type: :request do
  include ActiveJob::TestHelper

  let(:user) do
    User.create!(
      email: 'req_platform_user@example.com',
      password: 'Password123!',
      confirmed_at: Time.current
    )
  end

  let(:auth_token) { Authenticable.encode_jwt({ user_id: user.id }) }
  let(:headers) { { 'Authorization' => "Bearer #{auth_token}", 'Accept' => 'application/json' } }

  let(:campaign) do
    Campaign.create!(
      user: user,
      name: 'Omnichannel Campaign',
      objective: 'OUTCOME_SALES',
      budget: 1500.0,
      status: 'active'
    )
  end

  let(:account_fb) do
    PlatformAccount::Facebook.create!(
      user: user,
      account_id: 'act_req_fb_123',
      name: 'Store FB Ads',
      access_token: 'fb_token_req',
      status: 'connected'
    )
  end

  describe 'Route constraints' do
    it 'accepts facebook and google platforms' do
      post "/v1/facebook/campaigns/#{campaign.id}/publish",
           params: { platform_account_ids: [ account_fb.id ] },
           headers: headers
      expect(response).not_to have_http_status(:not_found)

      post "/v1/google/campaigns/#{campaign.id}/publish",
           params: { platform_account_ids: [ account_fb.id ] },
           headers: headers
      expect(response).not_to have_http_status(:not_found)
    end

    it 'rejects unsupported platform with 404 routing error' do
      post "/v1/tiktok/campaigns/#{campaign.id}/publish",
           params: { platform_account_ids: [ account_fb.id ] },
           headers: headers
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST /v1/:platform/campaigns/:id/publish' do
    context 'when unauthenticated' do
      it 'returns 401 unauthorized' do
        post "/v1/facebook/campaigns/#{campaign.id}/publish",
             params: { platform_account_ids: [ account_fb.id ] },
             headers: { 'Accept' => 'application/json' }

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with valid parameters (JSON)' do
      it 'creates pending platform campaign, enqueues SyncCampaignJob, and returns 200' do
        expect do
          post "/v1/facebook/campaigns/#{campaign.id}/publish",
               params: { platform_account_ids: [ account_fb.id ] },
               headers: headers
        end.to have_enqueued_job(SyncCampaignJob)

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json['platform_campaigns']).to be_an(Array)
        expect(json['platform_campaigns'].first['sync_status']).to eq('pending')
      end
    end

    context 'with browser HTML request' do
      it 'redirects to campaign_path with notice upon success' do
        cookies[:jwt_token] = auth_token

        post "/v1/facebook/campaigns/#{campaign.id}/publish",
             params: { platform_account_ids: [ account_fb.id ] }

        expect(response).to redirect_to(campaign_path(campaign))
        follow_redirect!
        expect(flash[:notice]).to be_present
      end
    end

    context 'with validation failure (no accounts selected)' do
      it 'returns 422 with validation errors' do
        post "/v1/facebook/campaigns/#{campaign.id}/publish",
             params: { platform_account_ids: [] },
             headers: headers

        expect(response).to have_http_status(:unprocessable_content)
        json = response.parsed_body
        expect(json['errors']).to be_present
      end
    end

    context 'when account was already published for this campaign' do
      before do
        PlatformCampaign.create!(
          campaign: campaign,
          platform_account: account_fb,
          sync_status: 'synced',
          external_campaign_id: 'fb_existing_001'
        )
      end

      it 'returns 422 with already published error' do
        post "/v1/facebook/campaigns/#{campaign.id}/publish",
             params: { platform_account_ids: [ account_fb.id ] },
             headers: headers

        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  describe 'POST /v1/:platform/campaigns/:id/resync' do
    let!(:platform_campaign) do
      PlatformCampaign.create!(
        campaign: campaign,
        platform_account: account_fb,
        external_campaign_id: 'fb_ext_req_001',
        sync_status: 'synced',
        synced_at: 1.day.ago
      )
    end

    context 'when campaign was updated after synced_at (drift detected)' do
      before do
        campaign.update_columns(updated_at: 10.minutes.ago)
      end

      it 'enqueues SyncCampaignJob and returns 200' do
        expect do
          post "/v1/facebook/campaigns/#{campaign.id}/resync",
               params: { platform_campaign_id: platform_campaign.id },
               headers: headers
        end.to have_enqueued_job(SyncCampaignJob).with(platform_campaign.id)

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json['message']).to include('Campaign resync initiated successfully')
      end

      it 'handles HTML browser request by redirecting to campaign_path' do
        cookies[:jwt_token] = auth_token

        post "/v1/facebook/campaigns/#{campaign.id}/resync",
             params: { platform_campaign_id: platform_campaign.id }

        expect(response).to redirect_to(campaign_path(campaign))
        follow_redirect!
        expect(flash[:notice]).to be_present
      end
    end

    context 'when no drift exists' do
      before do
        campaign.update_columns(updated_at: 2.days.ago)
        platform_campaign.update_columns(synced_at: 1.day.ago)
      end

      it 'returns 422 with error message' do
        post "/v1/facebook/campaigns/#{campaign.id}/resync",
             params: { platform_campaign_id: platform_campaign.id },
             headers: headers

        expect(response).to have_http_status(:unprocessable_content)
        json = response.parsed_body
        expect(json['error']).to include('No drift detected')
      end
    end
  end
end

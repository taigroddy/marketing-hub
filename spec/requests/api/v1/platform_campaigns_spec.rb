# frozen_string_literal: true

require "swagger_helper"

RSpec.describe "Api::V1::PlatformCampaigns", type: :request do
  include ActiveJob::TestHelper

  let(:user) do
    User.create!(
      email: "req_platform_user@example.com",
      password: "Password123!",
      confirmed_at: Time.current
    )
  end

  let(:auth_token) { Authenticable.encode_jwt({ user_id: user.id }) }
  let(:headers) { { "Authorization" => "Bearer #{auth_token}", "Accept" => "application/json" } }

  let(:campaign) do
    Campaign.create!(
      user: user,
      name: "Omnichannel Campaign",
      objective: "OUTCOME_SALES",
      budget: 1500.0,
      status: "active"
    )
  end

  let(:account_fb) do
    PlatformAccount::Facebook.create!(
      user: user,
      account_id: "act_req_fb_123",
      name: "Store FB Ads",
      access_token: "fb_token_req",
      status: "connected"
    )
  end

  path "/v1/{platform}/campaigns/{id}/publish" do
    parameter name: :platform, in: :path, type: :string, schema: { type: :string, enum: %w[facebook google] }, description: "Advertising platform (facebook or google)"
    parameter name: :id, in: :path, type: :integer, description: "Campaign ID"

    post "Publish a campaign to one or more platform ad accounts" do
      tags "Platform Campaigns"
      security [ bearerAuth: [] ]
      consumes "application/json"
      produces "application/json"
      parameter name: :payload, in: :body, schema: {
        type: :object,
        properties: {
          platform_account_ids: {
            type: :array,
            items: { type: :integer },
            example: [ 1 ]
          }
        },
        required: %w[platform_account_ids]
      }

      response 200, "Campaign publish initiated" do
        let(:platform) { "facebook" }
        let(:id) { campaign.id }
        let(:Authorization) { "Bearer #{auth_token}" }
        let(:payload) { { platform_account_ids: [ account_fb.id ] } }

        run_test! do |response|
          json = JSON.parse(response.body)
          expect(json["platform_campaigns"]).to be_an(Array)
          expect(json["platform_campaigns"].first["sync_status"]).to eq("pending")
        end
      end

      response 401, "Unauthorized" do
        let(:platform) { "facebook" }
        let(:id) { campaign.id }
        let(:Authorization) { nil }
        let(:payload) { { platform_account_ids: [ account_fb.id ] } }

        run_test!
      end

      response 422, "Validation error or already published" do
        let(:platform) { "facebook" }
        let(:id) { campaign.id }
        let(:Authorization) { "Bearer #{auth_token}" }
        let(:payload) { { platform_account_ids: [] } }

        run_test! do |response|
          json = JSON.parse(response.body)
          expect(json["errors"] || json["error"]).to be_present
        end
      end
    end
  end

  path "/v1/{platform}/campaigns/{id}/resync" do
    parameter name: :platform, in: :path, type: :string, schema: { type: :string, enum: %w[facebook google] }, description: "Advertising platform (facebook or google)"
    parameter name: :id, in: :path, type: :integer, description: "Campaign ID"

    post "Resynchronize campaign details to platform ad accounts" do
      tags "Platform Campaigns"
      security [ bearerAuth: [] ]
      consumes "application/json"
      produces "application/json"
      parameter name: :payload, in: :body, schema: {
        type: :object,
        properties: {
          platform_campaign_id: { type: :integer, example: 1 }
        }
      }

      let!(:platform_campaign) do
        PlatformCampaign.create!(
          campaign: campaign,
          platform_account: account_fb,
          external_campaign_id: "fb_ext_req_001",
          sync_status: "synced",
          synced_at: 1.day.ago
        )
      end

      response 200, "Campaign resync initiated" do
        let(:platform) { "facebook" }
        let(:id) { campaign.id }
        let(:Authorization) { "Bearer #{auth_token}" }
        let(:payload) { { platform_campaign_id: platform_campaign.id } }

        before do
          campaign.update_columns(updated_at: 10.minutes.ago)
        end

        run_test! do |response|
          json = JSON.parse(response.body)
          expect(json["message"]).to include("Campaign resync initiated successfully")
        end
      end

      response 422, "No drift detected or resync error" do
        let(:platform) { "facebook" }
        let(:id) { campaign.id }
        let(:Authorization) { "Bearer #{auth_token}" }
        let(:payload) { { platform_campaign_id: platform_campaign.id } }

        before do
          campaign.update_columns(updated_at: 2.days.ago)
          platform_campaign.update_columns(synced_at: 1.day.ago)
        end

        run_test! do |response|
          json = JSON.parse(response.body)
          expect(json["error"]).to include("No drift detected")
        end
      end
    end
  end

  describe "Additional platform campaign test cases" do
    it "rejects unsupported platform route constraint" do
      post "/v1/tiktok/campaigns/#{campaign.id}/publish",
           params: { platform_account_ids: [ account_fb.id ] },
           headers: headers
      expect(response).to have_http_status(:not_found)
    end

    it "handles HTML browser request on publish" do
      cookies[:jwt_token] = auth_token
      post "/v1/facebook/campaigns/#{campaign.id}/publish",
           params: { platform_account_ids: [ account_fb.id ] }
      expect(response).to redirect_to(campaign_path(campaign))
      follow_redirect!
      expect(flash[:notice]).to be_present
    end

    it "handles HTML browser request on resync" do
      p_camp = PlatformCampaign.create!(
        campaign: campaign,
        platform_account: account_fb,
        external_campaign_id: "fb_ext_req_002",
        sync_status: "synced",
        synced_at: 1.day.ago
      )
      campaign.update_columns(updated_at: 10.minutes.ago)
      cookies[:jwt_token] = auth_token

      post "/v1/facebook/campaigns/#{campaign.id}/resync",
           params: { platform_campaign_id: p_camp.id }
      expect(response).to redirect_to(campaign_path(campaign))
      follow_redirect!
      expect(flash[:notice]).to be_present
    end
  end
end

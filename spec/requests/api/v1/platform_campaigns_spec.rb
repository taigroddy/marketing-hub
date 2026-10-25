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

  path "/api/v1/{platform}/campaigns/{id}/publish" do
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
        schema type: :object,
               properties: {
                 success: { type: :boolean, example: true },
                 data: {
                   type: :object,
                   properties: {
                     platform_campaigns: {
                       type: :array,
                       items: { type: :object }
                     },
                     message: { type: :string }
                   }
                 },
                 errors: { nullable: true }
               },
               required: %w[success]

        let(:platform) { "facebook" }
        let(:id) { campaign.id }
        let(:Authorization) { "Bearer #{auth_token}" }
        let(:payload) { { platform_account_ids: [ account_fb.id ] } }

        run_test! do |response|
          json = JSON.parse(response.body)
          expect(json["success"]).to be true
          expect(json["errors"]).to be_nil
          expect(json["data"]["platform_campaigns"]).to be_an(Array)
          expect(json["data"]["platform_campaigns"].first["sync_status"]).to eq("pending")
        end
      end

      response 401, "Unauthorized" do
        schema type: :object,
               properties: {
                 success: { type: :boolean, example: false },
                 data: { nullable: true },
                 errors: { description: "Error details or validation hash" }
               },
               required: %w[success]

        let(:platform) { "facebook" }
        let(:id) { campaign.id }
        let(:Authorization) { nil }
        let(:payload) { { platform_account_ids: [ account_fb.id ] } }

        run_test! do |response|
          json = JSON.parse(response.body)
          expect(json["success"]).to be false
          expect(json["data"]).to be_nil
          expect(json["errors"]).to eq(I18n.t("errors.unauthorized"))
        end
      end

      response 404, "Campaign or platform account not found" do
        schema type: :object,
               properties: {
                 success: { type: :boolean, example: false },
                 data: { nullable: true },
                 errors: { description: "Error details or validation hash" }
               },
               required: %w[success]

        let(:platform) { "facebook" }
        let(:id) { 999_999 }
        let(:Authorization) { "Bearer #{auth_token}" }
        let(:payload) { { platform_account_ids: [ account_fb.id ] } }

        run_test! do |response|
          json = JSON.parse(response.body)
          expect(json["success"]).to be false
          expect(json["data"]).to be_nil
          expect(json["errors"]).to be_present
        end
      end

      response 409, "Already published for this campaign" do
        schema type: :object,
               properties: {
                 success: { type: :boolean, example: false },
                 data: { nullable: true },
                 errors: { description: "Error details or validation hash" }
               },
               required: %w[success]

        let(:platform) { "facebook" }
        let(:id) { campaign.id }
        let(:Authorization) { "Bearer #{auth_token}" }
        let(:payload) { { platform_account_ids: [ account_fb.id ] } }

        before do
          PlatformCampaign.create!(
            campaign: campaign,
            platform_account: account_fb,
            sync_status: "pending"
          )
        end

        run_test! do |response|
          json = JSON.parse(response.body)
          expect(json["success"]).to be false
          expect(json["data"]).to be_nil
          expect(json["errors"]).to be_present
        end
      end

      response 422, "Validation error" do
        schema type: :object,
               properties: {
                 success: { type: :boolean, example: false },
                 data: { nullable: true },
                 errors: { description: "Error details or validation hash" }
               },
               required: %w[success]

        let(:platform) { "facebook" }
        let(:id) { campaign.id }
        let(:Authorization) { "Bearer #{auth_token}" }
        let(:payload) { { platform_account_ids: [] } }

        run_test! do |response|
          json = JSON.parse(response.body)
          expect(json["success"]).to be false
          expect(json["data"]).to be_nil
          expect(json["errors"]).to be_present
        end
      end
    end
  end

  path "/api/v1/{platform}/campaigns/{id}/resync" do
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
        schema type: :object,
               properties: {
                 success: { type: :boolean, example: true },
                 data: {
                   type: :object,
                   properties: {
                     platform_campaigns: {
                       type: :array,
                       items: { type: :object }
                     },
                     message: { type: :string }
                   }
                 },
                 errors: { nullable: true }
               },
               required: %w[success]

        let(:platform) { "facebook" }
        let(:id) { campaign.id }
        let(:Authorization) { "Bearer #{auth_token}" }
        let(:payload) { { platform_campaign_id: platform_campaign.id } }

        before do
          campaign.update_columns(updated_at: 10.minutes.ago)
        end

        run_test! do |response|
          json = JSON.parse(response.body)
          expect(json["success"]).to be true
          expect(json["errors"]).to be_nil
          expect(json["data"]["message"]).to eq(I18n.t("platform_campaigns.messages.resync_initiated"))
        end
      end

      response 401, "Unauthorized" do
        schema type: :object,
               properties: {
                 success: { type: :boolean, example: false },
                 data: { nullable: true },
                 errors: { description: "Error details or validation hash" }
               },
               required: %w[success]

        let(:platform) { "facebook" }
        let(:id) { campaign.id }
        let(:Authorization) { nil }
        let(:payload) { { platform_campaign_id: platform_campaign.id } }

        run_test! do |response|
          json = JSON.parse(response.body)
          expect(json["success"]).to be false
          expect(json["data"]).to be_nil
          expect(json["errors"]).to eq(I18n.t("errors.unauthorized"))
        end
      end

      response 404, "Campaign or platform campaign not found" do
        schema type: :object,
               properties: {
                 success: { type: :boolean, example: false },
                 data: { nullable: true },
                 errors: { description: "Error details or validation hash" }
               },
               required: %w[success]

        let(:platform) { "facebook" }
        let(:id) { 999_999 }
        let(:Authorization) { "Bearer #{auth_token}" }
        let(:payload) { { platform_campaign_id: platform_campaign.id } }

        run_test! do |response|
          json = JSON.parse(response.body)
          expect(json["success"]).to be false
          expect(json["data"]).to be_nil
          expect(json["errors"]).to be_present
        end
      end

      response 422, "No drift detected or resync error" do
        schema type: :object,
               properties: {
                 success: { type: :boolean, example: false },
                 data: { nullable: true },
                 errors: { description: "Error details or validation hash" }
               },
               required: %w[success]

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
          expect(json["success"]).to be false
          expect(json["data"]).to be_nil
          expect(json["errors"]).to include(I18n.t("platform_campaigns.messages.no_drift_detected"))
        end
      end
    end
  end

  describe "Additional platform campaign test cases" do
    it "rejects unsupported platform route constraint" do
      post "/api/v1/tiktok/campaigns/#{campaign.id}/publish",
           params: { platform_account_ids: [ account_fb.id ] },
           headers: headers
      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 when publishing non-existent campaign" do
      post "/api/v1/facebook/campaigns/999999/publish",
           params: { platform_account_ids: [ account_fb.id ] },
           headers: headers,
           as: :json
      expect(response).to have_http_status(:not_found)
      json = JSON.parse(response.body)
      expect(json["success"]).to be false
      expect(json["data"]).to be_nil
      expect(json["errors"]).to be_present
    end

    it "returns 404 when publishing with non-existent or foreign platform account" do
      post "/api/v1/facebook/campaigns/#{campaign.id}/publish",
           params: { platform_account_ids: [ 999_999 ] },
           headers: headers,
           as: :json
      expect(response).to have_http_status(:not_found)
      json = JSON.parse(response.body)
      expect(json["success"]).to be false
      expect(json["data"]).to be_nil
      expect(json["errors"]).to be_present
    end

    it "returns 409 conflict when campaign is already published to platform account" do
      PlatformCampaign.create!(
        campaign: campaign,
        platform_account: account_fb,
        sync_status: "pending"
      )

      post "/api/v1/facebook/campaigns/#{campaign.id}/publish",
           params: { platform_account_ids: [ account_fb.id ] },
           headers: headers,
           as: :json
      expect(response).to have_http_status(:conflict)
      json = JSON.parse(response.body)
      expect(json["success"]).to be false
      expect(json["data"]).to be_nil
      expect(json["errors"]).to be_present
    end

    it "returns 404 when publishing to unsupported google platform" do
      post "/api/v1/google/campaigns/#{campaign.id}/publish",
           params: { platform_account_ids: [ account_fb.id ] },
           headers: headers,
           as: :json
      expect(response).to have_http_status(:not_found)
      json = JSON.parse(response.body)
      expect(json["success"]).to be false
      expect(json["data"]).to be_nil
      expect(json["errors"]).to include("Google platform integration coming soon")
    end

    it "returns 404 when resyncing non-existent campaign" do
      post "/api/v1/facebook/campaigns/999999/resync",
           params: { platform_campaign_id: 1 },
           headers: headers,
           as: :json
      expect(response).to have_http_status(:not_found)
      json = JSON.parse(response.body)
      expect(json["success"]).to be false
      expect(json["data"]).to be_nil
      expect(json["errors"]).to be_present
    end

    it "returns 404 when resyncing non-existent platform campaign" do
      post "/api/v1/facebook/campaigns/#{campaign.id}/resync",
           params: { platform_campaign_id: 999_999 },
           headers: headers,
           as: :json
      expect(response).to have_http_status(:not_found)
      json = JSON.parse(response.body)
      expect(json["success"]).to be false
      expect(json["data"]).to be_nil
      expect(json["errors"]).to be_present
    end

    it "returns 422 on resync validation error" do
      post "/api/v1/facebook/campaigns/%20/resync", headers: headers, as: :json
      expect(response).to have_http_status(:unprocessable_content)
      json = JSON.parse(response.body)
      expect(json["success"]).to be false
      expect(json["data"]).to be_nil
      expect(json["errors"]).to be_present
    end

    it "returns 422 when resyncing campaign without drift" do
      p_camp = PlatformCampaign.create!(
        campaign: campaign,
        platform_account: account_fb,
        external_campaign_id: "fb_ext_req_003",
        sync_status: "synced",
        synced_at: 1.day.ago
      )
      campaign.update_columns(updated_at: 2.days.ago)

      post "/api/v1/facebook/campaigns/#{campaign.id}/resync",
           params: { platform_campaign_id: p_camp.id },
           headers: headers,
           as: :json
      expect(response).to have_http_status(:unprocessable_content)
      json = JSON.parse(response.body)
      expect(json["success"]).to be false
      expect(json["errors"]).to include(I18n.t("platform_campaigns.messages.no_drift_detected"))
    end
  end
end

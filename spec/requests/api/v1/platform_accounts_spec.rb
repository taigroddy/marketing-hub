# frozen_string_literal: true

require "swagger_helper"

RSpec.describe "Api::V1::PlatformAccounts", type: :request do
  let(:user) do
    User.create!(
      email: "user-platform-req@example.com",
      password: "Password123!",
      confirmed_at: Time.current
    )
  end

  let(:jwt_token) { Authenticable.encode_jwt({ user_id: user.id }) }
  let(:headers) { { "Authorization" => "Bearer #{jwt_token}", "Accept" => "application/json" } }

  path "/v1/{platform}/oauth/authorize" do
    get "Initiate OAuth authorization with advertising platform" do
      tags "Platform Accounts"
      security [ bearerAuth: [] ]
      produces "application/json"
      parameter name: :platform, in: :path, type: :string, schema: { type: :string, enum: %w[facebook google] }, description: "Platform identifier (facebook or google)"
      parameter name: :state, in: :query, type: :string, required: false, description: "Anti-CSRF state token"
      parameter name: :redirect_uri, in: :query, type: :string, required: false, description: "Callback redirect URI"
      parameter name: :scope, in: :query, type: :string, required: false, description: "OAuth scope permissions"

      response 200, "OAuth authorization URL generated" do
        schema type: :object,
               properties: {
                 success: { type: :boolean, example: true },
                 data: {
                   type: :object,
                   properties: {
                     authorize_url: { type: :string }
                   }
                 },
                 errors: { nullable: true }
               },
               required: %w[success]

        let(:platform) { "facebook" }
        let(:state) { "xyz" }
        let(:redirect_uri) { nil }
        let(:scope) { nil }
        let(:Authorization) { "Bearer #{jwt_token}" }

        run_test! do |response|
          json = JSON.parse(response.body)
          expect(json["success"]).to be true
          expect(json["errors"]).to be_nil
          expect(json["data"]["authorize_url"]).to include("https://www.facebook.com/v21.0/dialog/oauth")
          expect(json["data"]["authorize_url"]).to include("client_id=")
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
        let(:state) { nil }
        let(:redirect_uri) { nil }
        let(:scope) { nil }
        let(:Authorization) { nil }

        run_test! do |response|
          json = JSON.parse(response.body)
          expect(json["success"]).to be false
          expect(json["data"]).to be_nil
          expect(json["errors"]).to eq("Unauthorized")
        end
      end

      response 501, "Platform integration coming soon" do
        schema type: :object,
               properties: {
                 success: { type: :boolean, example: false },
                 data: { nullable: true },
                 errors: { description: "Error details or validation hash" }
               },
               required: %w[success]

        let(:platform) { "google" }
        let(:state) { nil }
        let(:redirect_uri) { nil }
        let(:scope) { nil }
        let(:Authorization) { "Bearer #{jwt_token}" }

        run_test! do |response|
          json = JSON.parse(response.body)
          expect(json["success"]).to be false
          expect(json["data"]).to be_nil
          expect(json["errors"]).to include("Google platform integration coming soon")
        end
      end
    end
  end

  path "/v1/{platform}/oauth/callback" do
    get "OAuth callback to exchange authorization code for access token", vcr: { cassette_name: "facebook_oauth" } do
      tags "Platform Accounts"
      security [ bearerAuth: [] ]
      produces "application/json"
      parameter name: :platform, in: :path, type: :string, schema: { type: :string, enum: %w[facebook google] }, description: "Platform identifier (facebook or google)"
      parameter name: :code, in: :query, type: :string, required: true, description: "OAuth authorization code"

      response 200, "Platform account connected successfully" do
        schema type: :object,
               properties: {
                 success: { type: :boolean, example: true },
                 data: {
                   type: :object,
                   properties: {
                     platform_account: { type: :object },
                     message: { type: :string }
                   }
                 },
                 errors: { nullable: true }
               },
               required: %w[success]

        let(:platform) { "facebook" }
        let(:code) { "valid_auth_code" }
        let(:Authorization) { "Bearer #{jwt_token}" }

        run_test! do |response|
          json = JSON.parse(response.body)
          expect(json["success"]).to be true
          expect(json["errors"]).to be_nil
          expect(json["data"]["message"]).to eq("Platform account connected successfully")
          expect(json["data"]["platform_account"]["account_id"]).to eq("1015012345678")
          expect(json["data"]["platform_account"]).not_to have_key("access_token")
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
        let(:code) { "some_code" }
        let(:Authorization) { nil }

        run_test! do |response|
          json = JSON.parse(response.body)
          expect(json["success"]).to be false
          expect(json["data"]).to be_nil
          expect(json["errors"]).to eq("Unauthorized")
        end
      end

      response 422, "Validation or exchange error" do
        schema type: :object,
               properties: {
                 success: { type: :boolean, example: false },
                 data: { nullable: true },
                 errors: { description: "Error details or validation hash" }
               },
               required: %w[success]

        let(:platform) { "facebook" }
        let(:code) { "" }
        let(:Authorization) { "Bearer #{jwt_token}" }

        run_test! do |response|
          json = JSON.parse(response.body)
          expect(json["success"]).to be false
          expect(json["data"]).to be_nil
          expect(json["errors"]).to be_present
        end
      end
    end
  end

  path "/api/v1/platform_accounts" do
    get "List connected platform accounts" do
      tags "Platform Accounts"
      security [ bearerAuth: [] ]
      produces "application/json"

      let!(:fb_account) do
        PlatformAccount::Facebook.create!(
          user: user,
          account_id: "act_123",
          name: "My FB",
          access_token: "token_123",
          status: "connected"
        )
      end

      response 200, "List of connected platform accounts" do
        schema type: :object,
               properties: {
                 success: { type: :boolean, example: true },
                 data: {
                   type: :object,
                   properties: {
                     platform_accounts: {
                       type: :array,
                       items: { type: :object }
                     }
                   }
                 },
                 errors: { nullable: true }
               },
               required: %w[success]

        let(:Authorization) { "Bearer #{jwt_token}" }

        run_test! do |response|
          json = JSON.parse(response.body)
          expect(json["success"]).to be true
          expect(json["errors"]).to be_nil
          expect(json["data"]["platform_accounts"]).to be_an(Array)
          expect(json["data"]["platform_accounts"].first["account_id"]).to eq("act_123")
        end
      end
    end
  end

  describe "Platform accounts additional cases" do
    it "rejects unsupported platform route constraint" do
      get "/v1/unsupported_platform/oauth/authorize", headers: headers
      expect(response).to have_http_status(:not_found)
    end

    it "redirects to facebook OAuth dialog in html format" do
      get "/v1/facebook/oauth/authorize",
          headers: { "Authorization" => "Bearer #{jwt_token}", "Accept" => "text/html" }
      expect(response).to have_http_status(:found)
      expect(response.location).to include("https://www.facebook.com/v21.0/dialog/oauth")
    end

    it "returns 422 when Google platform callback is invoked" do
      get "/v1/google/oauth/callback", params: { code: "google_code" }, headers: headers
      expect(response).to have_http_status(:unprocessable_content)
      json = JSON.parse(response.body)
      expect(json["success"]).to be false
      expect(json["data"]).to be_nil
      expect(json["errors"]).to include("Google platform integration coming soon")
    end

    it "routes alias /oauth/:platform/callback to platform accounts callback" do
      get "/oauth/google/callback", params: { code: "google_code" }, headers: headers
      expect(response).to have_http_status(:unprocessable_content)
      json = JSON.parse(response.body)
      expect(json["success"]).to be false
      expect(json["data"]).to be_nil
      expect(json["errors"]).to include("Google platform integration coming soon")
    end

    it "redirects to dashboard when callback is requested as HTML", vcr: { cassette_name: "facebook_oauth" } do
      get "/v1/facebook/oauth/callback",
          params: { code: "valid_auth_code" },
          headers: { "Authorization" => "Bearer #{jwt_token}", "Accept" => "text/html" }
      expect(response).to redirect_to(dashboard_path)
      expect(flash[:notice]).to include("kết nối thành công")
    end

    it "redirects to dashboard with alert on failure when requested as HTML", vcr: { cassette_name: "facebook_oauth" } do
      get "/v1/facebook/oauth/callback",
          params: { code: "invalid_code" },
          headers: { "Authorization" => "Bearer #{jwt_token}", "Accept" => "text/html" }
      expect(response).to redirect_to(dashboard_path)
      expect(flash[:alert]).to include("Kết nối thất bại")
    end

    it "redirects to dashboard with alert on validation error when requested as HTML" do
      get "/v1/facebook/oauth/callback",
          params: { code: "" },
          headers: { "Authorization" => "Bearer #{jwt_token}", "Accept" => "text/html" }
      expect(response).to redirect_to(dashboard_path)
      expect(flash[:alert]).to include("Kết nối thất bại")
    end
  end
end

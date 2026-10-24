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
        let(:platform) { "facebook" }
        let(:state) { "xyz" }
        let(:redirect_uri) { nil }
        let(:scope) { nil }
        let(:Authorization) { "Bearer #{jwt_token}" }

        run_test! do |response|
          json = JSON.parse(response.body)
          expect(json["authorize_url"]).to include("https://www.facebook.com/v21.0/dialog/oauth")
          expect(json["authorize_url"]).to include("client_id=")
        end
      end

      response 401, "Unauthorized" do
        let(:platform) { "facebook" }
        let(:state) { nil }
        let(:redirect_uri) { nil }
        let(:scope) { nil }
        let(:Authorization) { nil }

        run_test!
      end

      response 501, "Platform integration coming soon" do
        let(:platform) { "google" }
        let(:state) { nil }
        let(:redirect_uri) { nil }
        let(:scope) { nil }
        let(:Authorization) { "Bearer #{jwt_token}" }

        run_test! do |response|
          json = JSON.parse(response.body)
          expect(json["error"]).to include("Google platform integration coming soon")
        end
      end
    end
  end

  path "/v1/{platform}/oauth/callback" do
    get "OAuth callback to exchange authorization code for access token" do
      tags "Platform Accounts"
      security [ bearerAuth: [] ]
      produces "application/json"
      parameter name: :platform, in: :path, type: :string, schema: { type: :string, enum: %w[facebook google] }, description: "Platform identifier (facebook or google)"
      parameter name: :code, in: :query, type: :string, required: true, description: "OAuth authorization code"

      let(:mock_client) { instance_double(Clients::OAuth::FacebookClient) }

      before do
        allow(Clients::OAuth::FacebookClient).to receive(:new).and_return(mock_client)
      end

      response 200, "Platform account connected successfully" do
        let(:platform) { "facebook" }
        let(:code) { "valid_fb_code" }
        let(:Authorization) { "Bearer #{jwt_token}" }

        before do
          allow(mock_client).to receive(:exchange_code).with(code: "valid_fb_code", redirect_uri: nil).and_return(
            Dry::Monads::Success(
              access_token: "eaab_valid_token_xyz",
              token_type: "bearer",
              expires_in: 5184000
            )
          )
          allow(mock_client).to receive(:fetch_ad_accounts).with("eaab_valid_token_xyz").and_return(
            Dry::Monads::Success(
              data: [
                { "id" => "act_99887766", "account_id" => "99887766", "name" => "Marketing Ad Account" }
              ]
            )
          )
        end

        run_test! do |response|
          json = JSON.parse(response.body)
          expect(json["message"]).to eq("Platform account connected successfully")
          expect(json["platform_account"]["account_id"]).to eq("99887766")
          expect(json["platform_account"]).not_to have_key("access_token")
        end
      end

      response 401, "Unauthorized" do
        let(:platform) { "facebook" }
        let(:code) { "some_code" }
        let(:Authorization) { nil }

        run_test!
      end

      response 422, "Validation or exchange error" do
        let(:platform) { "facebook" }
        let(:code) { "" }
        let(:Authorization) { "Bearer #{jwt_token}" }

        run_test! do |response|
          json = JSON.parse(response.body)
          expect(json["errors"] || json["error"]).to be_present
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
        let(:Authorization) { "Bearer #{jwt_token}" }

        run_test! do |response|
          json = JSON.parse(response.body)
          expect(json["platform_accounts"]).to be_an(Array)
          expect(json["platform_accounts"].first["account_id"]).to eq("act_123")
        end
      end
    end
  end

  describe "Platform accounts additional cases" do
    let(:mock_client) { instance_double(Clients::OAuth::FacebookClient) }

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
      expect(json["error"]).to include("Google platform integration coming soon")
    end

    it "redirects to dashboard when callback is requested as HTML" do
      allow(Clients::OAuth::FacebookClient).to receive(:new).and_return(mock_client)
      allow(mock_client).to receive(:exchange_code).with(code: "valid_fb_code", redirect_uri: nil).and_return(
        Dry::Monads::Success(access_token: "eaab_valid", token_type: "bearer", expires_in: 5184000)
      )
      allow(mock_client).to receive(:fetch_ad_accounts).with("eaab_valid").and_return(
        Dry::Monads::Success(data: [ { "id" => "act_1", "account_id" => "1", "name" => "Page" } ])
      )

      get "/v1/facebook/oauth/callback",
          params: { code: "valid_fb_code" },
          headers: { "Authorization" => "Bearer #{jwt_token}", "Accept" => "text/html" }
      expect(response).to redirect_to(dashboard_path)
      expect(flash[:notice]).to include("kết nối thành công")
    end

    it "redirects to dashboard with alert on failure when requested as HTML" do
      allow(Clients::OAuth::FacebookClient).to receive(:new).and_return(mock_client)
      allow(mock_client).to receive(:exchange_code).with(code: "invalid_code", redirect_uri: nil).and_return(
        Dry::Monads::Failure(error: "Invalid code")
      )

      get "/v1/facebook/oauth/callback",
          params: { code: "invalid_code" },
          headers: { "Authorization" => "Bearer #{jwt_token}", "Accept" => "text/html" }
      expect(response).to redirect_to(dashboard_path)
      expect(flash[:alert]).to include("Kết nối thất bại")
    end
  end
end

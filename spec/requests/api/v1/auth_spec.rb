# frozen_string_literal: true

require "swagger_helper"

RSpec.describe "Api::V1::Auth", type: :request do
  path "/api/v1/auth/register" do
    post "Register a new user" do
      tags "Authentication"
      consumes "application/json"
      produces "application/json"
      parameter name: :payload, in: :body, schema: {
        type: :object,
        properties: {
          email: { type: :string, example: "user@example.com" },
          password: { type: :string, example: "Password123!" },
          password_confirmation: { type: :string, example: "Password123!" }
        },
        required: %w[email password password_confirmation]
      }

      response 201, "User registered successfully" do
        schema type: :object,
               properties: {
                 success: { type: :boolean, example: true },
                 data: {
                   type: :object,
                   properties: {
                     message: { type: :string },
                     user: { type: :object }
                   }
                 },
                 errors: { nullable: true }
               },
               required: %w[success]

        let(:payload) do
          {
            email: "api-user@example.com",
            password: "Password123!",
            password_confirmation: "Password123!"
          }
        end

        run_test! do |response|
          json = JSON.parse(response.body)
          expect(json["success"]).to be true
          expect(json["errors"]).to be_nil
          expect(json["data"]["message"]).to include("Registration successful")
          expect(json["data"]["user"]["email"]).to eq("api-user@example.com")
          expect(json["data"]["user"]).not_to have_key("password_digest")
          expect(json["data"]["user"]).not_to have_key("confirmation_token")
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

        let(:payload) do
          {
            email: "invalid-email",
            password: "123",
            password_confirmation: "nomatch"
          }
        end

        run_test! do |response|
          json = JSON.parse(response.body)
          expect(json["success"]).to be false
          expect(json["data"]).to be_nil
          expect(json["errors"]).to be_present
        end
      end
    end
  end

  describe "Additional registration edge cases" do
    let(:valid_attributes) do
      {
        email: "existing@example.com",
        password: "Password123!",
        password_confirmation: "Password123!"
      }
    end

    it "rejects duplicate email" do
      User.create!(email: "existing@example.com", password: "Password123!", confirmation_token: "tok-dup")
      post "/api/v1/auth/register", params: valid_attributes, as: :json
      expect(response).to have_http_status(:unprocessable_content)
      json = JSON.parse(response.body)
      expect(json["success"]).to be false
      expect(json["data"]).to be_nil
      expect(json["errors"]["email"]).to include("has already been taken")
    end
  end

  path "/api/v1/auth/login" do
    post "Authenticate user and return JWT" do
      tags "Authentication"
      consumes "application/json"
      produces "application/json"
      parameter name: :payload, in: :body, schema: {
        type: :object,
        properties: {
          email: { type: :string, example: "login-user@example.com" },
          password: { type: :string, example: "Password123!" }
        },
        required: %w[email password]
      }

      let!(:user) do
        User.create!(
          email: "login-user@example.com",
          password: "Password123!",
          confirmed_at: 1.day.ago
        )
      end

      response 200, "Login successful" do
        schema type: :object,
               properties: {
                 success: { type: :boolean, example: true },
                 data: {
                   type: :object,
                   properties: {
                     token: { type: :string },
                     refresh_token: { type: :string },
                     user: { type: :object }
                   }
                 },
                 errors: { nullable: true }
               },
               required: %w[success]

        let(:payload) { { email: "login-user@example.com", password: "Password123!" } }

        run_test! do |response|
          json = JSON.parse(response.body)
          expect(json["success"]).to be true
          expect(json["errors"]).to be_nil
          expect(json["data"]["token"]).to be_present
          expect(json["data"]["refresh_token"]).to be_present
          expect(json["data"]["user"]["id"]).to eq(user.id)
          expect(json["data"]["user"]["email"]).to eq("login-user@example.com")
          decoded = Authenticable.decode_jwt(json["data"]["token"])
          expect(decoded[:user_id]).to eq(user.id)
        end
      end

      response 401, "Invalid credentials" do
        schema type: :object,
               properties: {
                 success: { type: :boolean, example: false },
                 data: { nullable: true },
                 errors: { description: "Error details or validation hash" }
               },
               required: %w[success]

        let(:payload) { { email: "login-user@example.com", password: "WrongPassword!" } }

        run_test! do |response|
          json = JSON.parse(response.body)
          expect(json["success"]).to be false
          expect(json["data"]).to be_nil
          expect(json["errors"]).to include("Invalid email or password")
        end
      end

      response 403, "Unconfirmed email address" do
        schema type: :object,
               properties: {
                 success: { type: :boolean, example: false },
                 data: { nullable: true },
                 errors: { description: "Error details or validation hash" }
               },
               required: %w[success]

        let!(:unconfirmed_user) do
          User.create!(
            email: "unconfirmed@example.com",
            password: "Password123!",
            confirmation_token: "tok-unconf"
          )
        end
        let(:payload) { { email: "unconfirmed@example.com", password: "Password123!" } }

        run_test! do |response|
          json = JSON.parse(response.body)
          expect(json["success"]).to be false
          expect(json["data"]).to be_nil
          expect(json["errors"]).to include("confirm your email")
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

        let(:payload) { { email: "invalid-email", password: "" } }

        run_test! do |response|
          json = JSON.parse(response.body)
          expect(json["success"]).to be false
          expect(json["data"]).to be_nil
          expect(json["errors"]).to be_present
        end
      end
    end
  end

  path "/api/v1/auth/refresh" do
    post "Refresh access token using refresh token" do
      tags "Authentication"
      consumes "application/json"
      produces "application/json"
      parameter name: :payload, in: :body, schema: {
        type: :object,
        properties: {
          refresh_token: { type: :string, example: "a1b2c3d4..." }
        },
        required: %w[refresh_token]
      }

      let!(:user) do
        User.create!(
          email: "refresh-user@example.com",
          password: "Password123!",
          confirmed_at: 1.day.ago
        )
      end
      let!(:token_pair) { UserToken.create_for_user!(user) }
      let(:raw_token) { token_pair.last }

      response 200, "Token refreshed successfully" do
        schema type: :object,
               properties: {
                 success: { type: :boolean, example: true },
                 data: {
                   type: :object,
                   properties: {
                     token: { type: :string },
                     refresh_token: { type: :string },
                     user: { type: :object }
                   }
                 },
                 errors: { nullable: true }
               },
               required: %w[success]

        let(:payload) { { refresh_token: raw_token } }

        run_test! do |response|
          json = JSON.parse(response.body)
          expect(json["success"]).to be true
          expect(json["errors"]).to be_nil
          expect(json["data"]["token"]).to be_present
          expect(json["data"]["refresh_token"]).to be_present
          expect(json["data"]["refresh_token"]).not_to eq(raw_token)
          expect(json["data"]["user"]["id"]).to eq(user.id)
        end
      end

      response 401, "Invalid or expired refresh token" do
        schema type: :object,
               properties: {
                 success: { type: :boolean, example: false },
                 data: { nullable: true },
                 errors: { description: "Error details or validation hash" }
               },
               required: %w[success]

        let(:payload) { { refresh_token: "invalid-token" } }

        run_test! do |response|
          json = JSON.parse(response.body)
          expect(json["success"]).to be false
          expect(json["data"]).to be_nil
          expect(json["errors"]).to include("Invalid or expired")
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

        let(:payload) { { refresh_token: "" } }

        run_test! do |response|
          json = JSON.parse(response.body)
          expect(json["success"]).to be false
          expect(json["data"]).to be_nil
          expect(json["errors"]).to be_present
        end
      end
    end
  end

  path "/api/v1/auth/logout" do
    post "Revoke refresh token and logout device" do
      tags "Authentication"
      consumes "application/json"
      produces "application/json"
      parameter name: :payload, in: :body, schema: {
        type: :object,
        properties: {
          refresh_token: { type: :string, example: "a1b2c3d4..." }
        },
        required: %w[refresh_token]
      }

      let!(:user) do
        User.create!(
          email: "logout-user@example.com",
          password: "Password123!",
          confirmed_at: 1.day.ago
        )
      end
      let!(:token_pair) { UserToken.create_for_user!(user) }
      let(:raw_token) { token_pair.last }

      response 200, "Logged out successfully" do
        schema type: :object,
               properties: {
                 success: { type: :boolean, example: true },
                 data: {
                   type: :object,
                   properties: {
                     message: { type: :string }
                   }
                 },
                 errors: { nullable: true }
               },
               required: %w[success]

        let(:payload) { { refresh_token: raw_token } }

        run_test! do |response|
          json = JSON.parse(response.body)
          expect(json["success"]).to be true
          expect(json["errors"]).to be_nil
          expect(json["data"]["message"]).to eq("Logged out successfully.")
          expect(token_pair.first.reload.revoked?).to be true
        end
      end

      response 401, "Invalid or expired refresh token" do
        schema type: :object,
               properties: {
                 success: { type: :boolean, example: false },
                 data: { nullable: true },
                 errors: { description: "Error details or validation hash" }
               },
               required: %w[success]

        let(:payload) { { refresh_token: "nonexistent-token" } }

        run_test! do |response|
          json = JSON.parse(response.body)
          expect(json["success"]).to be false
          expect(json["data"]).to be_nil
          expect(json["errors"]).to include("Invalid or expired")
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

        let(:payload) { { refresh_token: "" } }

        run_test! do |response|
          json = JSON.parse(response.body)
          expect(json["success"]).to be false
          expect(json["data"]).to be_nil
          expect(json["errors"]).to be_present
        end
      end
    end
  end

  path "/api/v1/auth/confirm/{token}" do
    get "Confirm user email address" do
      tags "Authentication"
      produces "application/json"
      parameter name: :token, in: :path, type: :string, description: "Confirmation token sent via email"

      let!(:user) do
        User.create!(
          email: "confirm-target@example.com",
          password: "Password123!",
          confirmation_token: "secret-token-123",
          confirmation_sent_at: 10.minutes.ago
        )
      end

      response 200, "Email confirmed successfully" do
        schema type: :object,
               properties: {
                 success: { type: :boolean, example: true },
                 data: {
                   type: :object,
                   properties: {
                     token: { type: :string },
                     user: { type: :object },
                     message: { type: :string }
                   }
                 },
                 errors: { nullable: true }
               },
               required: %w[success]

        let(:token) { "secret-token-123" }

        run_test! do |response|
          json = JSON.parse(response.body)
          expect(json["success"]).to be true
          expect(json["errors"]).to be_nil
          expect(json["data"]["token"]).to be_present
          expect(json["data"]["message"]).to include("Email confirmed successfully")
          expect(user.reload.confirmed?).to be true
          expect(user.confirmation_token).to be_nil
        end
      end

      response 422, "Invalid or expired token" do
        schema type: :object,
               properties: {
                 success: { type: :boolean, example: false },
                 data: { nullable: true },
                 errors: { description: "Error details or validation hash" }
               },
               required: %w[success]

        let(:token) { "wrong-token" }

        run_test! do |response|
          json = JSON.parse(response.body)
          expect(json["success"]).to be false
          expect(json["data"]).to be_nil
          expect(json["errors"]).to include("Invalid or expired")
        end
      end
    end
  end

  path "/api/v1/auth/me" do
    get "Get current authenticated user profile" do
      tags "Authentication"
      security [ bearerAuth: [] ]
      produces "application/json"

      let!(:user) do
        User.create!(
          email: "me-test@example.com",
          password: "Password123!",
          confirmed_at: 1.day.ago
        )
      end

      response 200, "Profile retrieved successfully" do
        schema type: :object,
               properties: {
                 success: { type: :boolean, example: true },
                 data: {
                   type: :object,
                   properties: {
                     user: { type: :object }
                   }
                 },
                 errors: { nullable: true }
               },
               required: %w[success]

        let(:Authorization) { "Bearer #{Authenticable.encode_jwt({ user_id: user.id })}" }

        run_test! do |response|
          json = JSON.parse(response.body)
          expect(json["success"]).to be true
          expect(json["errors"]).to be_nil
          expect(json["data"]["user"]["id"]).to eq(user.id)
          expect(json["data"]["user"]["email"]).to eq("me-test@example.com")
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

        let(:Authorization) { "Bearer invalid_token" }

        run_test! do |response|
          json = JSON.parse(response.body)
          expect(json["success"]).to be false
          expect(json["data"]).to be_nil
          expect(json["errors"]).to eq("Unauthorized")
        end
      end
    end
  end

  describe "Multi-device authentication workflow" do
    let!(:user) do
      User.create!(
        email: "multi-device@example.com",
        password: "Password123!",
        confirmed_at: 1.day.ago
      )
    end

    it "supports independent login, refresh, and logout across multiple devices" do
      # 1. Login on Device A
      post "/api/v1/auth/login",
           params: { email: user.email, password: "Password123!" },
           headers: { "User-Agent" => "Device-A-iOS" },
           as: :json
      expect(response).to have_http_status(:ok)
      device_a_tokens = JSON.parse(response.body)["data"]
      token_a = device_a_tokens["token"]
      refresh_a = device_a_tokens["refresh_token"]

      # 2. Login on Device B
      post "/api/v1/auth/login",
           params: { email: user.email, password: "Password123!" },
           headers: { "User-Agent" => "Device-B-Android" },
           as: :json
      expect(response).to have_http_status(:ok)
      device_b_tokens = JSON.parse(response.body)["data"]
      token_b = device_b_tokens["token"]
      refresh_b = device_b_tokens["refresh_token"]

      expect(refresh_a).not_to eq(refresh_b)

      # 3. Both devices can access /me
      get "/api/v1/auth/me", headers: { "Authorization" => "Bearer #{token_a}" }
      expect(response).to have_http_status(:ok)
      me_body = JSON.parse(response.body)
      expect(me_body["success"]).to be true
      expect(me_body["data"]["user"]["id"]).to eq(user.id)

      get "/api/v1/auth/me", headers: { "Authorization" => "Bearer #{token_b}" }
      expect(response).to have_http_status(:ok)
      me_body = JSON.parse(response.body)
      expect(me_body["success"]).to be true
      expect(me_body["data"]["user"]["id"]).to eq(user.id)

      # 4. Device A refreshes token
      post "/api/v1/auth/refresh",
           params: { refresh_token: refresh_a },
           headers: { "User-Agent" => "Device-A-iOS" },
           as: :json
      expect(response).to have_http_status(:ok)
      refreshed_a = JSON.parse(response.body)["data"]
      new_token_a = refreshed_a["token"]
      new_refresh_a = refreshed_a["refresh_token"]
      expect(new_refresh_a).not_to eq(refresh_a)

      # 5. Device B is unaffected by Device A's refresh
      get "/api/v1/auth/me", headers: { "Authorization" => "Bearer #{token_b}" }
      expect(response).to have_http_status(:ok)

      post "/api/v1/auth/refresh",
           params: { refresh_token: refresh_b },
           headers: { "User-Agent" => "Device-B-Android" },
           as: :json
      expect(response).to have_http_status(:ok)
      refreshed_b = JSON.parse(response.body)["data"]
      new_token_b = refreshed_b["token"]
      new_refresh_b = refreshed_b["refresh_token"]

      # 6. Device A logs out
      post "/api/v1/auth/logout",
           params: { refresh_token: new_refresh_a },
           as: :json
      expect(response).to have_http_status(:ok)

      # 7. Device A's refreshed token cannot refresh anymore
      post "/api/v1/auth/refresh",
           params: { refresh_token: new_refresh_a },
           as: :json
      expect(response).to have_http_status(:unauthorized)
      unauth_res = JSON.parse(response.body)
      expect(unauth_res["success"]).to be false
      expect(unauth_res["errors"]).to be_present

      # 8. Device B is still completely active and can access /me and refresh
      get "/api/v1/auth/me", headers: { "Authorization" => "Bearer #{new_token_b}" }
      expect(response).to have_http_status(:ok)

      post "/api/v1/auth/refresh",
           params: { refresh_token: new_refresh_b },
           as: :json
      expect(response).to have_http_status(:ok)
    end

    it "safely truncates User-Agent headers longer than 255 characters on login and refresh" do
      long_ua = "Specialized-Agent/2.0 " + ("K" * 320)

      post "/api/v1/auth/login",
           params: { email: user.email, password: "Password123!" },
           headers: { "User-Agent" => long_ua },
           as: :json
      expect(response).to have_http_status(:ok)
      data = JSON.parse(response.body)["data"]

      decoded = Authenticable.decode_jwt(data["token"])
      token_record = UserToken.find(decoded[:user_token_id])
      expect(token_record.device_info.length).to eq(255)
      expect(token_record.device_info).to eq(long_ua[0, 255])

      longer_refresh_ua = "Refreshed-Agent/3.0 " + ("M" * 320)
      post "/api/v1/auth/refresh",
           params: { refresh_token: data["refresh_token"] },
           headers: { "User-Agent" => longer_refresh_ua },
           as: :json
      expect(response).to have_http_status(:ok)
      token_record.reload
      expect(token_record.device_info.length).to eq(255)
      expect(token_record.device_info).to eq(longer_refresh_ua[0, 255])
    end
  end
end

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
        let(:payload) do
          {
            email: "api-user@example.com",
            password: "Password123!",
            password_confirmation: "Password123!"
          }
        end

        run_test! do |response|
          json = JSON.parse(response.body)
          expect(json["message"]).to include("Registration successful")
          expect(json["user"]["email"]).to eq("api-user@example.com")
          expect(json["user"]).not_to have_key("password_digest")
          expect(json["user"]).not_to have_key("confirmation_token")
        end
      end

      response 422, "Validation error" do
        let(:payload) do
          {
            email: "invalid-email",
            password: "123",
            password_confirmation: "nomatch"
          }
        end

        run_test! do |response|
          json = JSON.parse(response.body)
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
        let(:payload) { { email: "login-user@example.com", password: "Password123!" } }

        run_test! do |response|
          json = JSON.parse(response.body)
          expect(json["token"]).to be_present
          expect(json["user"]["id"]).to eq(user.id)
          expect(json["user"]["email"]).to eq("login-user@example.com")
          decoded = Authenticable.decode_jwt(json["token"])
          expect(decoded[:user_id]).to eq(user.id)
        end
      end

      response 401, "Invalid credentials" do
        let(:payload) { { email: "login-user@example.com", password: "WrongPassword!" } }

        run_test! do |response|
          json = JSON.parse(response.body)
          expect(json["error"]).to include("Invalid email or password")
        end
      end

      response 403, "Unconfirmed email address" do
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
          expect(json["error"]).to include("confirm your email")
        end
      end

      response 422, "Validation error" do
        let(:payload) { { email: "invalid-email", password: "" } }

        run_test! do |response|
          json = JSON.parse(response.body)
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
        let(:token) { "secret-token-123" }

        run_test! do |response|
          json = JSON.parse(response.body)
          expect(json["token"]).to be_present
          expect(json["message"]).to include("Email confirmed successfully")
          expect(user.reload.confirmed?).to be true
          expect(user.confirmation_token).to be_nil
        end
      end

      response 422, "Invalid or expired token" do
        let(:token) { "wrong-token" }

        run_test! do |response|
          json = JSON.parse(response.body)
          expect(json["error"]).to include("Invalid or expired")
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
        let(:Authorization) { "Bearer #{Authenticable.encode_jwt({ user_id: user.id })}" }

        run_test! do |response|
          json = JSON.parse(response.body)
          expect(json["user"]["id"]).to eq(user.id)
          expect(json["user"]["email"]).to eq("me-test@example.com")
        end
      end

      response 401, "Unauthorized" do
        let(:Authorization) { "Bearer invalid_token" }

        run_test! do |response|
          json = JSON.parse(response.body)
          expect(json["error"]).to eq("Unauthorized")
        end
      end
    end
  end
end

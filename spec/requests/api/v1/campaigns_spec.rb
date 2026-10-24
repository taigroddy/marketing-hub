# frozen_string_literal: true

require "swagger_helper"

RSpec.describe "Api::V1::Campaigns", type: :request do
  let(:user_a) do
    User.create!(
      email: "user-a@example.com",
      password: "Password123!",
      confirmed_at: Time.current
    )
  end

  let(:user_b) do
    User.create!(
      email: "user-b@example.com",
      password: "Password123!",
      confirmed_at: Time.current
    )
  end

  let(:token_a) { Authenticable.encode_jwt({ user_id: user_a.id }) }
  let(:token_b) { Authenticable.encode_jwt({ user_id: user_b.id }) }

  let(:headers_a) { { "Authorization" => "Bearer #{token_a}" } }
  let(:headers_b) { { "Authorization" => "Bearer #{token_b}" } }

  let!(:campaign_a) do
    Campaign.create!(
      user: user_a,
      name: "User A Camp",
      objective: "OUTCOME_TRAFFIC",
      budget: 1000.00,
      status: "draft"
    )
  end

  let!(:campaign_b) do
    Campaign.create!(
      user: user_b,
      name: "User B Camp",
      objective: "OUTCOME_LEADS",
      budget: 2000.00,
      status: "draft"
    )
  end

  path "/api/v1/campaigns" do
    get "List campaigns for current user" do
      tags "Campaigns"
      security [ bearerAuth: [] ]
      produces "application/json"

      response 200, "Campaigns retrieved successfully" do
        let(:Authorization) { "Bearer #{token_a}" }

        run_test! do |response|
          json = JSON.parse(response.body)
          campaign_ids = json["campaigns"].map { |c| c["id"] }
          expect(campaign_ids).to include(campaign_a.id)
          expect(campaign_ids).not_to include(campaign_b.id)
        end
      end

      response 401, "Unauthorized" do
        let(:Authorization) { nil }

        run_test!
      end
    end

    post "Create a new campaign" do
      tags "Campaigns"
      security [ bearerAuth: [] ]
      consumes "application/json"
      produces "application/json"
      parameter name: :payload, in: :body, schema: {
        type: :object,
        properties: {
          name: { type: :string, example: "Brand Awareness 2026" },
          objective: { type: :string, example: "OUTCOME_AWARENESS" },
          budget: { type: :number, format: :float, example: 5000.00 }
        },
        required: %w[name objective budget]
      }

      response 201, "Campaign created successfully" do
        let(:Authorization) { "Bearer #{token_a}" }
        let(:payload) do
          {
            name: "Brand Awareness 2026",
            objective: "OUTCOME_AWARENESS",
            budget: 5000.00
          }
        end

        run_test! do |response|
          json = JSON.parse(response.body)
          expect(json["campaign"]["name"]).to eq("Brand Awareness 2026")
          expect(json["campaign"]["user_id"]).to eq(user_a.id)
        end
      end

      response 401, "Unauthorized" do
        let(:Authorization) { nil }
        let(:payload) { { name: "Test", objective: "OUTCOME_TRAFFIC", budget: 100 } }

        run_test!
      end

      response 422, "Validation error" do
        let(:Authorization) { "Bearer #{token_a}" }
        let(:payload) { { name: "", objective: "", budget: -10 } }

        run_test! do |response|
          json = JSON.parse(response.body)
          expect(json["errors"]).to be_present
        end
      end
    end
  end

  path "/api/v1/campaigns/{id}" do
    parameter name: :id, in: :path, type: :integer, description: "Campaign ID"

    get "Get campaign details" do
      tags "Campaigns"
      security [ bearerAuth: [] ]
      produces "application/json"

      response 200, "Campaign details retrieved" do
        let(:Authorization) { "Bearer #{token_a}" }
        let(:id) { campaign_a.id }

        run_test! do |response|
          json = JSON.parse(response.body)
          expect(json["campaign"]["id"]).to eq(campaign_a.id)
          expect(json["campaign"]["name"]).to eq("User A Camp")
        end
      end

      response 401, "Unauthorized" do
        let(:Authorization) { nil }
        let(:id) { campaign_a.id }

        run_test!
      end

      response 404, "Campaign not found" do
        let(:Authorization) { "Bearer #{token_a}" }
        let(:id) { 999_999 }

        run_test!
      end
    end

    patch "Update campaign budget" do
      tags "Campaigns"
      security [ bearerAuth: [] ]
      consumes "application/json"
      produces "application/json"
      parameter name: :payload, in: :body, schema: {
        type: :object,
        properties: {
          budget: { type: :number, format: :float, example: 3500.00 }
        },
        required: %w[budget]
      }

      response 200, "Campaign budget updated" do
        let(:Authorization) { "Bearer #{token_a}" }
        let(:id) { campaign_a.id }
        let(:payload) { { budget: 3500.00 } }

        run_test! do |response|
          json = JSON.parse(response.body)
          expect(BigDecimal(json["campaign"]["budget"].to_s)).to eq(3500.00)
          expect(campaign_a.reload.budget).to eq(3500.00)
        end
      end

      response 401, "Unauthorized" do
        let(:Authorization) { nil }
        let(:id) { campaign_a.id }
        let(:payload) { { budget: 2000.00 } }

        run_test!
      end

      response 404, "Campaign not found" do
        let(:Authorization) { "Bearer #{token_b}" }
        let(:id) { campaign_a.id }
        let(:payload) { { budget: 9999.00 } }

        run_test!
      end

      response 422, "Validation error" do
        let(:Authorization) { "Bearer #{token_a}" }
        let(:id) { campaign_a.id }
        let(:payload) { { budget: -50 } }

        run_test! do |response|
          json = JSON.parse(response.body)
          expect(json["errors"]).to have_key("budget")
        end
      end
    end
  end

  describe "Additional campaign test cases" do
    it "ignores spoofed user_id in payload and preserves tenant isolation" do
      post "/api/v1/campaigns",
           params: { name: "Spoof test", objective: "OUTCOME_TRAFFIC", budget: 100, user_id: user_b.id },
           headers: headers_a,
           as: :json

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json["campaign"]["user_id"]).to eq(user_a.id)
    end

    it "ignores fields other than budget on update (budget-only editing)" do
      patch "/api/v1/campaigns/#{campaign_a.id}",
            params: {
              budget: 4500.00,
              name: "Injected Campaign Name",
              objective: "INJECTED_OBJECTIVE"
            },
            headers: headers_a,
            as: :json

      expect(response).to have_http_status(:ok)
      campaign_a.reload
      expect(campaign_a.budget).to eq(4500.00)
      expect(campaign_a.name).to eq("User A Camp")
      expect(campaign_a.objective).to eq("OUTCOME_TRAFFIC")
    end
  end
end

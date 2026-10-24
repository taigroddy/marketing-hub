# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::Campaigns', type: :request do
  let(:user_a) do
    User.create!(
      email: 'user-a@example.com',
      password: 'Password123!',
      confirmed_at: Time.current
    )
  end

  let(:user_b) do
    User.create!(
      email: 'user-b@example.com',
      password: 'Password123!',
      confirmed_at: Time.current
    )
  end

  let(:token_a) { Authenticable.encode_jwt({ user_id: user_a.id }) }
  let(:token_b) { Authenticable.encode_jwt({ user_id: user_b.id }) }

  let(:headers_a) { { 'Authorization' => "Bearer #{token_a}" } }
  let(:headers_b) { { 'Authorization' => "Bearer #{token_b}" } }

  let!(:campaign_a) do
    Campaign.create!(
      user: user_a,
      name: 'User A Camp',
      objective: 'OUTCOME_TRAFFIC',
      budget: 1000.00,
      status: 'draft'
    )
  end

  let!(:campaign_b) do
    Campaign.create!(
      user: user_b,
      name: 'User B Camp',
      objective: 'OUTCOME_LEADS',
      budget: 2000.00,
      status: 'draft'
    )
  end

  describe 'GET /api/v1/campaigns' do
    context 'when authenticated as user A' do
      it 'returns only campaigns belonging to user A' do
        get '/api/v1/campaigns', headers: headers_a

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        campaign_ids = json['campaigns'].map { |c| c['id'] }
        expect(campaign_ids).to include(campaign_a.id)
        expect(campaign_ids).not_to include(campaign_b.id)
      end
    end

    context 'when unauthenticated' do
      it 'returns 401 unauthorized' do
        get '/api/v1/campaigns'
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'GET /api/v1/campaigns/:id' do
    context 'when authenticated as owner' do
      it 'returns campaign details' do
        get "/api/v1/campaigns/#{campaign_a.id}", headers: headers_a

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['campaign']['id']).to eq(campaign_a.id)
        expect(json['campaign']['name']).to eq('User A Camp')
        expect(json['campaign']['user_id']).to eq(user_a.id)
      end
    end

    context 'when accessing another user campaign (strict tenant isolation)' do
      it 'returns 404 not found' do
        get "/api/v1/campaigns/#{campaign_a.id}", headers: headers_b

        expect(response).to have_http_status(:not_found)
        json = JSON.parse(response.body)
        expect(json['error']).to eq('Campaign not found')
      end
    end

    context 'when campaign does not exist' do
      it 'returns 404 not found' do
        get '/api/v1/campaigns/999999', headers: headers_a

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when unauthenticated' do
      it 'returns 401 unauthorized' do
        get "/api/v1/campaigns/#{campaign_a.id}"

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'POST /api/v1/campaigns' do
    let(:valid_payload) do
      {
        name: 'Brand Awareness 2026',
        objective: 'OUTCOME_AWARENESS',
        budget: 5000.00
      }
    end

    context 'when authenticated' do
      it 'creates campaign scoped to authenticated user and returns 201' do
        expect do
          post '/api/v1/campaigns', params: valid_payload, headers: headers_a, as: :json
        end.to change(user_a.campaigns, :count).by(1)

        expect(response).to have_http_status(:created)
        json = JSON.parse(response.body)
        expect(json['campaign']['name']).to eq('Brand Awareness 2026')
        expect(json['campaign']['user_id']).to eq(user_a.id)
      end

      it 'ignores spoofed user_id in payload and preserves tenant isolation' do
        post '/api/v1/campaigns',
             params: valid_payload.merge(user_id: user_b.id),
             headers: headers_a,
             as: :json

        expect(response).to have_http_status(:created)
        json = JSON.parse(response.body)
        expect(json['campaign']['user_id']).to eq(user_a.id)
        expect(json['campaign']['user_id']).not_to eq(user_b.id)
      end

      it 'returns 422 with errors when params are invalid' do
        post '/api/v1/campaigns',
             params: { name: '', objective: '', budget: -10 },
             headers: headers_a,
             as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json['errors']).to be_present
      end
    end

    context 'when unauthenticated' do
      it 'returns 401 unauthorized' do
        post '/api/v1/campaigns', params: valid_payload, as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'PATCH /api/v1/campaigns/:id' do
    context 'when authenticated as owner' do
      it 'updates only budget and returns 200' do
        patch "/api/v1/campaigns/#{campaign_a.id}",
              params: { budget: 3500.00 },
              headers: headers_a,
              as: :json

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(BigDecimal(json['campaign']['budget'].to_s)).to eq(3500.00)
        expect(campaign_a.reload.budget).to eq(3500.00)
      end

      it 'ignores fields other than budget (budget-only editing)' do
        patch "/api/v1/campaigns/#{campaign_a.id}",
              params: {
                budget: 4500.00,
                name: 'Injected Campaign Name',
                objective: 'INJECTED_OBJECTIVE'
              },
              headers: headers_a,
              as: :json

        expect(response).to have_http_status(:ok)
        campaign_a.reload
        expect(campaign_a.budget).to eq(4500.00)
        expect(campaign_a.name).to eq('User A Camp')
        expect(campaign_a.objective).to eq('OUTCOME_TRAFFIC')
      end

      it 'returns 422 when budget is invalid' do
        patch "/api/v1/campaigns/#{campaign_a.id}",
              params: { budget: -50 },
              headers: headers_a,
              as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json['errors']).to have_key('budget')
        expect(campaign_a.reload.budget).to eq(1000.00)
      end
    end

    context 'when authenticated user tries to update another user campaign' do
      it 'returns 404 not found and leaves campaign untouched' do
        patch "/api/v1/campaigns/#{campaign_a.id}",
              params: { budget: 9999.00 },
              headers: headers_b,
              as: :json

        expect(response).to have_http_status(:not_found)
        expect(campaign_a.reload.budget).to eq(1000.00)
      end
    end

    context 'when unauthenticated' do
      it 'returns 401 unauthorized' do
        patch "/api/v1/campaigns/#{campaign_a.id}",
              params: { budget: 2000.00 },
              as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end

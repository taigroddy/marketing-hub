# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Campaigns Web UI', type: :request do
  let(:user_a) do
    User.create!(
      email: 'web-user-a@example.com',
      password: 'Password123!',
      confirmed_at: Time.current
    )
  end

  let(:user_b) do
    User.create!(
      email: 'web-user-b@example.com',
      password: 'Password123!',
      confirmed_at: Time.current
    )
  end

  let(:token_a) { Authenticable.encode_jwt({ user_id: user_a.id }) }
  let(:token_b) { Authenticable.encode_jwt({ user_id: user_b.id }) }

  let!(:campaign_a) do
    Campaign.create!(
      user: user_a,
      name: 'User A Web Campaign',
      objective: 'OUTCOME_TRAFFIC',
      budget: 1500.00,
      status: 'draft'
    )
  end

  describe 'GET /dashboard' do
    context 'when user has campaigns' do
      it 'renders Section 2 with user campaign list, "Tạo mới" button, and "View detail" link' do
        cookies[:jwt_token] = token_a
        get '/dashboard'

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('Campaigns')
        expect(response.body).to include('User A Web Campaign')
        expect(response.body).to include('/campaigns/new')
        expect(response.body).to include('Tạo mới')
        expect(response.body).to include('View detail')
        expect(response.body).to include("/campaigns/#{campaign_a.id}")
      end
    end

    context 'when user has no campaigns' do
      it 'renders empty state with "Tạo campaign đầu tiên" and link to /campaigns/new' do
        cookies[:jwt_token] = token_b
        get '/dashboard'

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('Tạo campaign đầu tiên')
        expect(response.body).to include('/campaigns/new')
      end
    end
  end

  describe 'GET /campaigns' do
    it 'renders campaigns index successfully' do
      cookies[:jwt_token] = token_a
      get '/campaigns'

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('User A Web Campaign')
    end
  end

  describe 'GET /campaigns/:id' do
    context 'when owner' do
      let!(:fb_account_1) do
        PlatformAccount::Facebook.create!(
          user: user_a,
          account_id: 'act_ui_111',
          name: 'FB Store UI 1',
          access_token: 'token_ui_1',
          status: 'connected'
        )
      end

      let!(:fb_account_2) do
        PlatformAccount::Facebook.create!(
          user: user_a,
          account_id: 'act_ui_222',
          name: 'FB Store UI 2',
          access_token: 'token_ui_2',
          status: 'connected'
        )
      end

      it 'renders Section 1 with campaign details and edit button' do
        cookies[:jwt_token] = token_a
        get "/campaigns/#{campaign_a.id}"

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('User A Web Campaign')
        expect(response.body).to include('OUTCOME_TRAFFIC')
        expect(response.body).to include('1500.00')
        expect(response.body).to include('Chỉnh sửa')
        expect(response.body).to include("/campaigns/#{campaign_a.id}/edit")
        expect(response.body).to include('turbo-cable-stream-source')
        expect(response.body).to include('Turbo::StreamsChannel')
      end

      it 'renders Section 2 with connected accounts, checkboxes, and disables already published accounts' do
        PlatformCampaign.create!(
          campaign: campaign_a,
          platform_account: fb_account_1,
          sync_status: 'synced',
          external_campaign_id: 'fb_ext_ui_1',
          synced_at: 1.hour.ago
        )

        cookies[:jwt_token] = token_a
        get "/campaigns/#{campaign_a.id}"

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('id="platform_accounts_section"')
        expect(response.body).to include('FB Store UI 1')
        expect(response.body).to include('FB Store UI 2')
        expect(response.body).to include('Sync to platform')
        expect(response.body).to include('disabled')
        expect(response.body).to include('Đã xuất bản')
        expect(response.body).to include('Sẵn sàng đồng bộ')
      end

      it 'renders Section 3 with linked campaigns, shows "Sai lệch" badge and "Re-sync" button on drift' do
        pc = PlatformCampaign.create!(
          campaign: campaign_a,
          platform_account: fb_account_1,
          sync_status: 'synced',
          external_campaign_id: 'fb_ext_drift_007',
          synced_at: 2.hours.ago
        )
        campaign_a.update_columns(updated_at: 10.minutes.ago)

        cookies[:jwt_token] = token_a
        get "/campaigns/#{campaign_a.id}"

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('id="platform_campaigns_section"')
        expect(response.body).to include('fb_ext_drift_007')
        expect(response.body).to include('Sai lệch')
        expect(response.body).to include('Re-sync')
        expect(response.body).to include("/v1/facebook/campaigns/#{campaign_a.id}/resync")
      end
    end

    context 'when accessing another user campaign' do
      it 'redirects to dashboard with alert' do
        cookies[:jwt_token] = token_b
        get "/campaigns/#{campaign_a.id}"

        expect(response).to redirect_to(dashboard_path)
        follow_redirect!
        expect(flash[:alert]).to eq('Campaign not found')
      end
    end

    context 'when campaign does not exist' do
      it 'redirects to dashboard with alert' do
        cookies[:jwt_token] = token_a
        get '/campaigns/999999'

        expect(response).to redirect_to(dashboard_path)
        follow_redirect!
        expect(flash[:alert]).to eq('Campaign not found')
      end
    end
  end

  describe 'GET /campaigns/new' do
    it 'renders new campaign form with name, objective, and budget fields' do
      cookies[:jwt_token] = token_a
      get '/campaigns/new'

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('name')
      expect(response.body).to include('objective')
      expect(response.body).to include('budget')
    end
  end

  describe 'POST /campaigns' do
    context 'with valid parameters' do
      it 'creates campaign and redirects to dashboard' do
        cookies[:jwt_token] = token_a
        expect do
          post '/campaigns', params: {
            campaign: {
              name: 'New Web Camp',
              objective: 'OUTCOME_LEADS',
              budget: '2000'
            }
          }
        end.to change(user_a.campaigns, :count).by(1)

        expect(response).to redirect_to(dashboard_path)
        follow_redirect!
        expect(response.body).to include('Campaign created successfully')
      end
    end

    context 'with invalid parameters' do
      it 'renders new form with 422 unprocessable entity' do
        cookies[:jwt_token] = token_a
        expect do
          post '/campaigns', params: {
            campaign: {
              name: '',
              objective: '',
              budget: '-10'
            }
          }
        end.not_to change(Campaign, :count)

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'when service returns generic failure' do
      it 'renders new form with error message' do
        cookies[:jwt_token] = token_a
        allow_any_instance_of(Campaign).to receive(:save).and_return(false)

        post '/campaigns', params: {
          campaign: {
            name: 'Valid',
            objective: 'OUTCOME_TRAFFIC',
            budget: '500'
          }
        }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(flash[:alert]).to be_present
      end
    end
  end

  describe 'GET /campaigns/:id/edit' do
    context 'when owner' do
      it 'renders edit form with name and objective disabled and budget editable' do
        cookies[:jwt_token] = token_a
        get "/campaigns/#{campaign_a.id}/edit"

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('disabled')
        expect(response.body).to include(campaign_a.name)
        expect(response.body).to include('budget')
      end
    end

    context 'when accessing another user campaign (strict tenant isolation)' do
      it 'redirects to dashboard with alert' do
        cookies[:jwt_token] = token_b
        get "/campaigns/#{campaign_a.id}/edit"

        expect(response).to redirect_to(dashboard_path)
        follow_redirect!
        expect(flash[:alert]).to be_present
      end
    end

    context 'when campaign does not exist' do
      it 'redirects to dashboard with alert' do
        cookies[:jwt_token] = token_a
        get '/campaigns/999999/edit'

        expect(response).to redirect_to(dashboard_path)
        follow_redirect!
        expect(flash[:alert]).to eq('Campaign not found')
      end
    end
  end

  describe 'PATCH /campaigns/:id' do
    context 'when owner updates budget' do
      it 'updates budget and redirects to dashboard' do
        cookies[:jwt_token] = token_a
        patch "/campaigns/#{campaign_a.id}", params: {
          campaign: {
            budget: '3200.00',
            name: 'Attempted Name Change'
          }
        }

        expect(response).to redirect_to(dashboard_path)
        campaign_a.reload
        expect(campaign_a.budget).to eq(3200.00)
        expect(campaign_a.name).to eq('User A Web Campaign')
      end
    end

    context 'when validation fails' do
      it 'renders edit form with 422 unprocessable entity' do
        cookies[:jwt_token] = token_a
        patch "/campaigns/#{campaign_a.id}", params: {
          campaign: { budget: '-50' }
        }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(flash[:alert]).to be_present
      end
    end

    context 'when updating another user campaign' do
      it 'redirects to dashboard with alert and does not modify campaign' do
        cookies[:jwt_token] = token_b
        patch "/campaigns/#{campaign_a.id}", params: {
          campaign: { budget: '9999.00' }
        }

        expect(response).to redirect_to(dashboard_path)
        expect(campaign_a.reload.budget).to eq(1500.00)
      end
    end
  end
end

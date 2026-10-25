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
        expect(response.body).to include('id="campaign_header_section"')
        expect(response.body).to include('User A Web Campaign')
        expect(response.body).to include('OUTCOME_TRAFFIC')
        expect(response.body).to include('1.500 ₫')
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
        expect(response.body).to include('data-platform="facebook"')
        expect(response.body).to include("data-campaign-id=\"#{campaign_a.id}\"")
      end
    end

    context 'when accessing another user campaign' do
      it 'renders 404 not found page' do
        cookies[:jwt_token] = token_b
        get "/campaigns/#{campaign_a.id}"

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when campaign does not exist' do
      it 'renders 404 not found page' do
        cookies[:jwt_token] = token_a
        get '/campaigns/999999'

        expect(response).to have_http_status(:not_found)
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

  describe 'GET /campaigns/:id/edit' do
    context 'when owner' do
      it 'renders edit form with name and objective disabled and budget editable' do
        cookies[:jwt_token] = token_a
        get "/campaigns/#{campaign_a.id}/edit"

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('disabled')
        expect(response.body).to include(campaign_a.name)
        expect(response.body).to include('budget')
        expect(response.body).to include("/campaigns/#{campaign_a.id}")
      end
    end

    context 'when accessing another user campaign (strict tenant isolation)' do
      it 'renders 404 not found page' do
        cookies[:jwt_token] = token_b
        get "/campaigns/#{campaign_a.id}/edit"

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when campaign does not exist' do
      it 'renders 404 not found page' do
        cookies[:jwt_token] = token_a
        get '/campaigns/999999/edit'

        expect(response).to have_http_status(:not_found)
      end
    end
  end
end

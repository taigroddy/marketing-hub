# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Confirmations', type: :request do
  describe 'GET /confirm_email/:token' do
    it 'renders the confirmation HTML page with HTTP 200' do
      get '/confirm_email/sample-token-123'

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq('text/html')
      expect(response.body).to include('Đang xác thực email của bạn')
      expect(response.body).to include('sample-token-123')
      expect(cookies[:jwt_token]).to be_blank
    end
  end
end

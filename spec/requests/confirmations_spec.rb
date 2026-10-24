# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Confirmations', type: :request do
  let!(:user) do
    User.create!(
      email: 'click-confirm@example.com',
      password: 'Password123!',
      confirmation_token: 'link-token-777',
      confirmation_sent_at: 10.minutes.ago
    )
  end

  describe 'GET /confirm_email/:token' do
    context 'with valid token' do
      it 'activates account, sets jwt_token cookie, and redirects to /dashboard' do
        get '/confirm_email/link-token-777'

        expect(response).to redirect_to('/dashboard')
        expect(flash[:notice]).to include('confirmed successfully')
        expect(cookies[:jwt_token]).to be_present

        decoded = Authenticable.decode_jwt(cookies[:jwt_token])
        expect(decoded[:user_id]).to eq(user.id)

        user.reload
        expect(user.confirmed?).to be true
        expect(user.confirmation_token).to be_nil
      end
    end

    context 'with invalid or expired token' do
      it 'redirects to /login with alert when token does not exist' do
        get '/confirm_email/bogus-token'

        expect(response).to redirect_to('/login')
        expect(flash[:alert]).to include('Invalid or expired')
        expect(cookies[:jwt_token]).to be_blank
      end

      it 'redirects to /login with alert when token is expired' do
        user.update_column(:confirmation_sent_at, 2.days.ago)
        get '/confirm_email/link-token-777'

        expect(response).to redirect_to('/login')
        expect(flash[:alert]).to include('Invalid or expired')
        expect(cookies[:jwt_token]).to be_blank
        expect(user.reload.confirmed?).to be false
      end
    end
  end
end

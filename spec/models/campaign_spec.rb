# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Campaign, type: :model do
  let(:user) do
    User.create!(
      email: 'campaign-owner@example.com',
      password: 'Password123!',
      confirmed_at: Time.current
    )
  end

  subject(:campaign) do
    described_class.new(
      user: user,
      name: 'Summer Sale 2026',
      objective: 'OUTCOME_TRAFFIC',
      budget: 1500.50,
      status: 'draft'
    )
  end

  describe 'associations' do
    it 'belongs to user' do
      expect(campaign.user).to eq(user)
    end

    it 'has many platform_campaigns with dependent destroy' do
      assoc = described_class.reflect_on_association(:platform_campaigns)
      expect(assoc.macro).to eq(:has_many)
      expect(assoc.options[:dependent]).to eq(:destroy)
    end

    it 'has many platform_accounts through platform_campaigns' do
      assoc = described_class.reflect_on_association(:platform_accounts)
      expect(assoc.macro).to eq(:has_many)
      expect(assoc.options[:through]).to eq(:platform_campaigns)
    end
  end

  describe 'database constraints' do
    it 'raises ActiveRecord::NotNullViolation when name is null' do
      expect do
        described_class.create!(
          user: user,
          name: nil,
          objective: 'OUTCOME_LEADS',
          budget: 100.0
        )
      end.to raise_error(ActiveRecord::NotNullViolation)
    end

    it 'raises ActiveRecord::NotNullViolation when objective is null' do
      expect do
        described_class.create!(
          user: user,
          name: 'Promo',
          objective: nil,
          budget: 100.0
        )
      end.to raise_error(ActiveRecord::NotNullViolation)
    end

    it 'raises ActiveRecord::NotNullViolation when budget is null' do
      expect do
        described_class.create!(
          user: user,
          name: 'Promo',
          objective: 'OUTCOME_LEADS',
          budget: nil
        )
      end.to raise_error(ActiveRecord::NotNullViolation)
    end
  end

  describe 'database defaults' do
    it 'defaults status to draft' do
      new_campaign = described_class.create!(
        user: user,
        name: 'Promo',
        objective: 'OUTCOME_LEADS',
        budget: 100.0
      )
      expect(new_campaign.status).to eq('draft')
    end
  end

  describe 'dependent destroy' do
    it 'destroys dependent platform_campaigns when campaign is destroyed' do
      campaign.save!
      account = PlatformAccount::Facebook.create!(
        user: user,
        account_id: 'act_camp_cascade',
        name: 'FB',
        access_token: 'secret_token_123',
        status: 'connected'
      )
      PlatformCampaign.create!(
        campaign: campaign,
        platform_account: account,
        sync_status: 'pending'
      )

      expect { campaign.destroy }.to change(PlatformCampaign, :count).by(-1)
    end
  end

  describe 'zero callback job triggers' do
    it 'does not enqueue any background jobs on save' do
      expect do
        campaign.save!
      end.not_to have_enqueued_job
    end
  end
end

# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CampaignBlueprint do
  let(:user) do
    User.create!(
      email: 'bp-user@example.com',
      password: 'Password123!',
      confirmed_at: Time.current
    )
  end

  let(:campaign) do
    Campaign.create!(
      user: user,
      name: 'Spring Promo',
      objective: 'OUTCOME_TRAFFIC',
      budget: 1500.50,
      status: 'draft'
    )
  end

  describe '.render_as_hash' do
    it 'serializes expected campaign fields' do
      hash = described_class.render_as_hash(campaign)

      expect(hash).to include(
        id: campaign.id,
        user_id: user.id,
        name: 'Spring Promo',
        objective: 'OUTCOME_TRAFFIC',
        budget: campaign.budget,
        status: 'draft'
      )
    end
  end
end

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
  end

  describe 'validations' do
    it 'is valid with valid attributes' do
      expect(campaign).to be_valid
    end

    it 'requires a user' do
      campaign.user = nil
      expect(campaign).not_to be_valid
      expect(campaign.errors[:user]).to be_present
    end

    it 'requires a name' do
      campaign.name = nil
      expect(campaign).not_to be_valid
      expect(campaign.errors[:name]).to include("can't be blank")
    end

    it 'requires an objective' do
      campaign.objective = nil
      expect(campaign).not_to be_valid
      expect(campaign.errors[:objective]).to include("can't be blank")
    end

    it 'requires a budget' do
      campaign.budget = nil
      expect(campaign).not_to be_valid
      expect(campaign.errors[:budget]).to include("can't be blank")
    end

    it 'requires budget to be greater than 0' do
      campaign.budget = 0
      expect(campaign).not_to be_valid
      expect(campaign.errors[:budget]).to include('must be greater than 0')

      campaign.budget = -10
      expect(campaign).not_to be_valid
      expect(campaign.errors[:budget]).to include('must be greater than 0')
    end

    it 'requires status to be in allowed list' do
      campaign.status = 'invalid_status'
      expect(campaign).not_to be_valid
      expect(campaign.errors[:status]).to include('is not included in the list')
    end

    it 'defaults status to draft' do
      new_campaign = described_class.new(user: user, name: 'Promo', objective: 'OUTCOME_LEADS', budget: 100)
      expect(new_campaign.status).to eq('draft')
    end
  end

  describe 'tenant cascade' do
    it 'is destroyed when user is destroyed' do
      campaign.save!
      expect { user.destroy }.to change(described_class, :count).by(-1)
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

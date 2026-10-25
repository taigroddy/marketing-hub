# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Campaigns::UpdateBudgetService do
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

  let!(:campaign_a) do
    Campaign.create!(
      user: user_a,
      name: 'User A Campaign',
      objective: 'OUTCOME_TRAFFIC',
      budget: 1000.00,
      status: 'draft'
    )
  end

  before do
    Current.user = user_a
  end

  after do
    Current.user = nil
  end

  describe '.call' do
    context 'with valid budget' do
      it 'updates campaign budget and returns success' do
        result = described_class.call(id: campaign_a.id, budget: 2500.50)

        expect(result).to be_success
        updated = result.value![:campaign]
        expect(updated.reload.budget).to eq(2500.50)
      end

      it 'allows explicit user and campaign objects passed in input' do
        Current.user = nil
        result = described_class.call(campaign: campaign_a, user: user_a, budget: 3500.00)

        expect(result).to be_success
        expect(campaign_a.reload.budget).to eq(3500.00)
      end

      it 'ignores any other fields besides budget (budget-only editing)' do
        result = described_class.call(
          id: campaign_a.id,
          budget: 3000.00,
          name: 'Hacked Name',
          objective: 'OUTCOME_LEADS',
          status: 'completed'
        )

        expect(result).to be_success
        campaign_a.reload
        expect(campaign_a.budget).to eq(3000.00)
        expect(campaign_a.name).to eq('User A Campaign')
        expect(campaign_a.objective).to eq('OUTCOME_TRAFFIC')
        expect(campaign_a.status).to eq('draft')
      end

      it 'supports matcher block syntax' do
        matched_success = false

        described_class.call(id: campaign_a.id, budget: 1800.00) do |m|
          m.success do |data|
            matched_success = true
            expect(data[:campaign].reload.budget).to eq(1800.00)
          end

          m.failure(:validation) do |_errors|
            raise 'Should not hit validation failure'
          end

          m.failure do |_err|
            raise 'Should not hit generic failure'
          end
        end

        expect(matched_success).to be true
      end
    end

    context 'with invalid budget' do
      it 'fails validation when budget is zero' do
        result = described_class.call(id: campaign_a.id, budget: 0)

        expect(result).to be_failure
        expect(result.failure).to have_key(:budget)
      end

      it 'fails validation when budget is negative' do
        result = described_class.call(id: campaign_a.id, budget: -100)

        expect(result).to be_failure
        expect(result.failure).to have_key(:budget)
      end

      it 'fails validation when budget is blank' do
        result = described_class.call(id: campaign_a.id, budget: '')

        expect(result).to be_failure
        expect(result.failure).to have_key(:budget)
      end

      it 'matches failure(:validation) block' do
        matched_validation = false

        described_class.call(id: campaign_a.id, budget: -50) do |m|
          m.success do
            raise 'Should not hit success'
          end

          m.failure(:validation) do |errors|
            matched_validation = true
            expect(errors).to have_key(:budget)
          end

          m.failure do
            raise 'Should not hit generic failure'
          end
        end

        expect(matched_validation).to be true
      end
    end

    context 'strict tenant isolation' do
      before do
        Current.user = user_b
      end

      it 'returns failure(:not_found) when user B tries to update user A campaign' do
        result = described_class.call(id: campaign_a.id, budget: 5000.00)

        expect(result).to be_failure
        expect(result.failure).to eq(:not_found)
        expect(campaign_a.reload.budget).to eq(1000.00)
      end

      it 'matches failure(:check_resource) or generic failure for unauthorized access' do
        matched_not_found = false

        described_class.call(id: campaign_a.id, budget: 5000.00) do |m|
          m.success do
            raise 'Should not hit success'
          end

          m.failure(:validation) do
            raise 'Should not hit validation'
          end

          m.failure do |err|
            matched_not_found = true
            expect(err).to eq(:not_found)
          end
        end

        expect(matched_not_found).to be true
        expect(campaign_a.reload.budget).to eq(1000.00)
      end
    end

    context 'when campaign does not exist' do
      it 'returns failure(:not_found)' do
        result = described_class.call(id: 999_999, budget: 500.00)

        expect(result).to be_failure
        expect(result.failure).to eq(:not_found)
      end
    end

    context 'when unauthenticated' do
      before do
        Current.user = nil
      end

      it 'returns failure(:unauthorized)' do
        result = described_class.call(id: campaign_a.id, budget: 500.00)

        expect(result).to be_failure
        expect(result.failure).to eq(:unauthorized)
      end
    end
  end
end

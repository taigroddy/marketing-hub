# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Campaigns::CreateService do
  let(:user) do
    User.create!(
      email: 'owner@example.com',
      password: 'Password123!',
      confirmed_at: Time.current
    )
  end

  let(:other_user) do
    User.create!(
      email: 'other@example.com',
      password: 'Password123!',
      confirmed_at: Time.current
    )
  end

  let(:valid_params) do
    {
      name: 'Spring Promo',
      objective: 'OUTCOME_TRAFFIC',
      budget: 1200.00
    }
  end

  before do
    Current.user = user
  end

  after do
    Current.user = nil
  end

  describe '.call' do
    context 'with valid parameters' do
      it 'creates a new campaign for the authenticated user' do
        result = described_class.call(valid_params)

        expect(result).to be_success
        campaign = result.value![:campaign]
        expect(campaign).to be_persisted
        expect(campaign.user_id).to eq(user.id)
        expect(campaign.name).to eq('Spring Promo')
        expect(campaign.objective).to eq('OUTCOME_TRAFFIC')
        expect(campaign.budget).to eq(1200.00)
        expect(campaign.status).to eq('draft')
      end

      it 'enforces strict tenant isolation by ignoring user_id in params' do
        malicious_params = valid_params.merge(user_id: other_user.id)
        result = described_class.call(malicious_params)

        expect(result).to be_success
        campaign = result.value![:campaign]
        expect(campaign.user_id).to eq(user.id)
        expect(campaign.user_id).not_to eq(other_user.id)
      end

      it 'supports matcher block syntax' do
        matched_success = false

        described_class.call(valid_params) do |m|
          m.success do |data|
            matched_success = true
            expect(data[:campaign]).to be_persisted
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

    context 'with invalid parameters' do
      it 'returns failure on missing name' do
        result = described_class.call(valid_params.merge(name: ''))

        expect(result).to be_failure
        expect(result.failure).to have_key(:name)
      end

      it 'returns failure on missing objective' do
        result = described_class.call(valid_params.merge(objective: ''))

        expect(result).to be_failure
        expect(result.failure).to have_key(:objective)
      end

      it 'returns failure on non-positive budget' do
        result = described_class.call(valid_params.merge(budget: -50))

        expect(result).to be_failure
        expect(result.failure).to have_key(:budget)
      end

      it 'returns failure on zero budget' do
        result = described_class.call(valid_params.merge(budget: 0))

        expect(result).to be_failure
        expect(result.failure).to have_key(:budget)
      end

      it 'returns failure on invalid status' do
        result = described_class.call(valid_params.merge(status: 'invalid_status'))

        expect(result).to be_failure
        expect(result.failure).to have_key(:status)
      end

      it 'matches failure(:validation) block' do
        matched_val_failure = false

        described_class.call(valid_params.merge(name: '')) do |m|
          m.success do
            raise 'Should not succeed'
          end

          m.failure(:validation) do |errors|
            matched_val_failure = true
            expect(errors).to have_key(:name)
          end

          m.failure do
            raise 'Should not hit generic failure'
          end
        end

        expect(matched_val_failure).to be true
      end
    end
  end
end

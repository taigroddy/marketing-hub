# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Campaigns::CreateContract do
  subject(:contract) { described_class.new }

  let(:valid_params) do
    {
      name: 'Summer Sale',
      objective: 'OUTCOME_SALES',
      budget: 1500.50
    }
  end

  it 'passes with valid parameters' do
    result = contract.call(valid_params)
    expect(result).to be_success
  end

  it 'passes with valid status provided' do
    %w[draft active paused completed].each do |status|
      result = contract.call(valid_params.merge(status: status))
      expect(result).to be_success
    end
  end

  it 'fails when name is missing or empty' do
    expect(contract.call(valid_params.except(:name)).errors[:name]).to be_present
    expect(contract.call(valid_params.merge(name: '')).errors[:name]).to be_present
  end

  it 'fails when objective is missing or empty' do
    expect(contract.call(valid_params.except(:objective)).errors[:objective]).to be_present
    expect(contract.call(valid_params.merge(objective: '')).errors[:objective]).to be_present
  end

  it 'fails when budget is zero or negative' do
    expect(contract.call(valid_params.merge(budget: 0)).errors[:budget]).to be_present
    expect(contract.call(valid_params.merge(budget: -10)).errors[:budget]).to be_present
  end

  it 'fails when status is invalid' do
    result = contract.call(valid_params.merge(status: 'invalid_status'))
    expect(result).to be_failure
    expect(result.errors[:status]).to include('is not included in the list')
  end
end

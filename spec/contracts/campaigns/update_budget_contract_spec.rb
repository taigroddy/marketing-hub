# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Campaigns::UpdateBudgetContract do
  subject(:contract) { described_class.new }

  it 'passes with valid budget and id' do
    result = contract.call(id: 1, budget: 500.0)
    expect(result).to be_success
  end

  it 'passes with valid budget without id' do
    result = contract.call(budget: 500.0)
    expect(result).to be_success
  end

  it 'fails when budget is missing or blank' do
    expect(contract.call({}).errors[:budget]).to be_present
    expect(contract.call(budget: '').errors[:budget]).to be_present
  end

  it 'fails when budget is zero or negative' do
    expect(contract.call(budget: 0).errors[:budget]).to be_present
    expect(contract.call(budget: -50).errors[:budget]).to be_present
  end
end

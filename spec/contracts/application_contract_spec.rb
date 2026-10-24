# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ApplicationContract do
  let(:contract_class) do
    Class.new(ApplicationContract) do
      params do
        required(:name).filled(:string)
      end
    end
  end

  it 'inherits from Dry::Validation::Contract' do
    expect(ApplicationContract < Dry::Validation::Contract).to be true
  end

  it 'validates parameters correctly' do
    expect(contract_class.new.call(name: 'Valid').success?).to be true
    expect(contract_class.new.call(name: '').failure?).to be true
  end
end

# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Auth::ConfirmEmailContract do
  subject(:contract) { described_class.new }

  it 'passes with a valid string token' do
    result = contract.call(token: 'valid-confirmation-token-123')
    expect(result).to be_success
  end

  it 'fails when token is missing' do
    result = contract.call({})
    expect(result).to be_failure
    expect(result.errors[:token]).to be_present
  end

  it 'fails when token is an empty string' do
    result = contract.call(token: '')
    expect(result).to be_failure
    expect(result.errors[:token]).to be_present
  end

  it 'fails when token is nil' do
    result = contract.call(token: nil)
    expect(result).to be_failure
    expect(result.errors[:token]).to be_present
  end
end

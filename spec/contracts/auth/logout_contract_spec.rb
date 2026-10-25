# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Auth::LogoutContract do
  subject(:contract) { described_class.new }

  it 'passes with valid refresh_token' do
    result = contract.call(refresh_token: 'valid-refresh-token')
    expect(result).to be_success
  end

  it 'passes with valid user_token_id' do
    result = contract.call(user_token_id: 123)
    expect(result).to be_success
  end

  it 'passes when both refresh_token and user_token_id are provided' do
    result = contract.call(refresh_token: 'valid-refresh-token', user_token_id: 123)
    expect(result).to be_success
  end

  it 'fails when both are missing' do
    result = contract.call({})
    expect(result).to be_failure
    expect(result.errors[:refresh_token]).to be_present
  end

  it 'fails when refresh_token is blank and user_token_id is nil' do
    result = contract.call(refresh_token: '', user_token_id: nil)
    expect(result).to be_failure
    expect(result.errors[:refresh_token]).to be_present
  end
end

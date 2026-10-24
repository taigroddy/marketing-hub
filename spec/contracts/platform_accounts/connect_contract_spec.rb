# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PlatformAccounts::ConnectContract do
  subject(:contract) { described_class.new }

  it 'passes with valid required fields' do
    result = contract.call(platform: 'facebook', code: 'valid_code_123')
    expect(result).to be_success
  end

  it 'passes with optional fields provided' do
    result = contract.call(
      platform: 'facebook',
      code: 'valid_code_123',
      state: 'xyz_state',
      redirect_uri: 'http://localhost:3000/callback',
      account_id: 'act_12345',
      name: 'My Facebook Account'
    )
    expect(result).to be_success
  end

  it 'fails when platform is missing or empty' do
    expect(contract.call(code: 'code').errors[:platform]).to be_present
    expect(contract.call(platform: '', code: 'code').errors[:platform]).to be_present
  end

  it 'fails when code is missing or empty' do
    expect(contract.call(platform: 'facebook').errors[:code]).to be_present
    expect(contract.call(platform: 'facebook', code: '').errors[:code]).to be_present
  end
end

# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PlatformCampaigns::PublishContract do
  subject(:contract) { described_class.new }

  let(:valid_params) do
    {
      campaign_id: 1,
      platform: 'facebook',
      platform_account_ids: [ 10, 20 ]
    }
  end

  it 'passes with valid parameters' do
    result = contract.call(valid_params)
    expect(result).to be_success
  end

  it 'passes with id instead of campaign_id' do
    result = contract.call(valid_params.except(:campaign_id).merge(id: 1))
    expect(result).to be_success
  end

  it 'fails when platform is invalid' do
    result = contract.call(valid_params.merge(platform: 'tiktok'))
    expect(result).to be_failure
    expect(result.errors[:platform]).to be_present
  end

  it 'fails when platform_account_ids is empty' do
    result = contract.call(valid_params.merge(platform_account_ids: []))
    expect(result).to be_failure
    expect(result.errors[:platform_account_ids]).to be_present
  end

  it 'fails when both id and campaign_id are missing' do
    result = contract.call(valid_params.except(:campaign_id))
    expect(result).to be_failure
    expect(result.errors[:campaign_id]).to include('must be filled')
  end
end

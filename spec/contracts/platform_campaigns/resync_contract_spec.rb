# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PlatformCampaigns::ResyncContract do
  subject(:contract) { described_class.new }

  let(:valid_params) do
    {
      campaign_id: 1,
      platform: 'facebook',
      platform_campaign_id: 10
    }
  end

  it 'passes with valid parameters' do
    result = contract.call(valid_params)
    expect(result).to be_success
  end

  it 'passes without platform_campaign_id' do
    result = contract.call(valid_params.except(:platform_campaign_id))
    expect(result).to be_success
  end

  it 'fails when platform is invalid' do
    result = contract.call(valid_params.merge(platform: 'tiktok'))
    expect(result).to be_failure
    expect(result.errors[:platform]).to be_present
  end

  it 'fails when both id and campaign_id are missing' do
    result = contract.call(valid_params.except(:campaign_id))
    expect(result).to be_failure
    expect(result.errors[:campaign_id]).to include('must be filled')
  end
end

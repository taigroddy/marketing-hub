# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PlatformCampaigns::ResyncContract do
  subject(:contract) { described_class.new }

  let(:valid_params) do
    {
      id: 1,
      platform: 'facebook',
      platform_campaign_id: 10
    }
  end

  it 'passes with valid parameters' do
    result = contract.call(valid_params)
    expect(result).to be_success
  end

  it 'fails when id is missing' do
    result = contract.call(valid_params.except(:id))
    expect(result).to be_failure
    expect(result.errors[:id]).to include(I18n.t('dry_validation.errors.key?'))
  end

  it 'fails when platform_campaign_id is missing' do
    result = contract.call(valid_params.except(:platform_campaign_id))
    expect(result).to be_failure
    expect(result.errors[:platform_campaign_id]).to include(I18n.t('dry_validation.errors.key?'))
  end

  it 'fails when platform is invalid' do
    result = contract.call(valid_params.merge(platform: 'tiktok'))
    expect(result).to be_failure
    expect(result.errors[:platform]).to be_present
  end
end

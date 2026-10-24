# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Clients::AdCampaign::GoogleClient, type: :client do
  it 'aliases AdCampaign::GoogleClient to Clients::AdCampaign::GoogleClient' do
    expect(described_class).to eq(AdCampaign::GoogleClient)
  end

  it 'inherits from AdCampaign::BaseClient' do
    expect(described_class.superclass).to eq(AdCampaign::BaseClient)
  end

  describe '#initialize' do
    it 'raises NotImplementedError with message "Google platform integration coming soon"' do
      expect {
        described_class.new
      }.to raise_error(NotImplementedError, 'Google platform integration coming soon')
    end
  end

  describe 'methods on uninitialized instance' do
    let(:instance) { described_class.allocate }

    it 'raises NotImplementedError with message "Google platform integration coming soon"' do
      expect {
        instance.create_campaign
      }.to raise_error(NotImplementedError, 'Google platform integration coming soon')

      expect {
        instance.update_campaign
      }.to raise_error(NotImplementedError, 'Google platform integration coming soon')

      expect {
        instance.fetch_campaign
      }.to raise_error(NotImplementedError, 'Google platform integration coming soon')
    end
  end
end

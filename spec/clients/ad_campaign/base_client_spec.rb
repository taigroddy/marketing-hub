# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Clients::AdCampaign::BaseClient, type: :client do
  let(:client) { described_class.new }

  it 'aliases AdCampaign::BaseClient to Clients::AdCampaign::BaseClient' do
    expect(described_class).to eq(AdCampaign::BaseClient)
  end

  describe 'abstract methods' do
    it 'raises NotImplementedError on #create_campaign' do
      expect { client.create_campaign }.to raise_error(NotImplementedError, /must implement #create_campaign/)
    end

    it 'raises NotImplementedError on #update_campaign' do
      expect { client.update_campaign }.to raise_error(NotImplementedError, /must implement #update_campaign/)
    end

    it 'raises NotImplementedError on #fetch_campaign' do
      expect { client.fetch_campaign }.to raise_error(NotImplementedError, /must implement #fetch_campaign/)
    end
  end
end

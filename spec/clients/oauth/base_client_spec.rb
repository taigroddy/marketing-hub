# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Clients::OAuth::BaseClient, type: :client do
  let(:client) { described_class.new }

  it 'aliases OAuth::BaseClient to Clients::OAuth::BaseClient' do
    expect(described_class).to eq(OAuth::BaseClient)
  end

  describe 'abstract methods' do
    it 'raises NotImplementedError on #authorize_url' do
      expect { client.authorize_url }.to raise_error(NotImplementedError, /must implement #authorize_url/)
    end

    it 'raises NotImplementedError on #exchange_code' do
      expect { client.exchange_code(code: 'code') }.to raise_error(NotImplementedError, /must implement #exchange_code/)
    end

    it 'raises NotImplementedError on #refresh_token' do
      expect { client.refresh_token(refresh_token: 'token') }.to raise_error(NotImplementedError, /must implement #refresh_token/)
    end
  end
end

# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Clients::OAuth::GoogleClient, type: :client do
  it 'aliases OAuth::GoogleClient to Clients::OAuth::GoogleClient' do
    expect(described_class).to eq(OAuth::GoogleClient)
  end

  it 'inherits from OAuth::BaseClient' do
    expect(described_class.superclass).to eq(OAuth::BaseClient)
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
        instance.authorize_url
      }.to raise_error(NotImplementedError, 'Google platform integration coming soon')

      expect {
        instance.exchange_code(code: 'dummy')
      }.to raise_error(NotImplementedError, 'Google platform integration coming soon')

      expect {
        instance.refresh_token(refresh_token: 'dummy')
      }.to raise_error(NotImplementedError, 'Google platform integration coming soon')
    end
  end
end

# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Clients::AdCampaign::FacebookClient, type: :client do
  let(:access_token) { ENV['FB_TEST_ACCESS_TOKEN'].presence || '<FB_TEST_ACCESS_TOKEN>' }
  let(:account_id) { '2183515115230038' }
  let(:client) { described_class.new(access_token: access_token, account_id: account_id) }

  describe 'constants and aliases' do
    it 'aliases AdCampaign::FacebookClient to Clients::AdCampaign::FacebookClient' do
      expect(described_class).to eq(AdCampaign::FacebookClient)
    end

    it 'inherits from AdCampaign::BaseClient' do
      expect(described_class.superclass).to eq(AdCampaign::BaseClient)
    end
  end

  describe '#initialize' do
    it 'initializes with access_token and account_id' do
      expect(client.access_token).to eq(access_token)
      expect(client.account_id).to eq(account_id)
    end
  end

  describe '#create_campaign' do
    let(:valid_params) do
      {
        name: 'Summer Promo 2026',
        objective: 'OUTCOME_TRAFFIC',
        budget: 100_000.0,
        status: 'PAUSED'
      }
    end

    context 'when parameters are valid', vcr: { cassette_name: 'facebook_create_campaign_success' } do
      it 'creates campaign via FacebookAds SDK and returns Success with external id' do
        result = client.create_campaign(**valid_params)

        expect(result).to be_success
        expect(result.value![:id]).to eq('120252481465730228')
      end

      it 'normalizes account_id prefix if not already prefixed with act_' do
        client_with_raw_id = described_class.new(access_token: access_token, account_id: '2183515115230038')
        result = client_with_raw_id.create_campaign(**valid_params)

        expect(result).to be_success
        expect(result.value![:id]).to eq('120252481465730228')
      end

      it 'handles account_id that already starts with act_' do
        client_with_act = described_class.new(access_token: access_token, account_id: 'act_2183515115230038')
        result = client_with_act.create_campaign(**valid_params)

        expect(result).to be_success
        expect(result.value![:id]).to eq('120252481465730228')
      end

      it 'creates campaign without budget when budget is nil' do
        result = client.create_campaign(name: 'No Budget Promo', objective: 'OUTCOME_LEADS')
        expect(result).to be_success
        expect(result.value![:id]).to eq('120252481465730229')
      end
    end

    context 'when account_id is missing' do
      let(:client_without_account) { described_class.new(access_token: access_token) }

      it 'raises ArgumentError' do
        expect do
          client_without_account.create_campaign(**valid_params)
        end.to raise_error(ArgumentError, /account_id/)
      end
    end

    context 'when access_token is missing' do
      let(:client_without_token) { described_class.new(account_id: account_id) }

      it 'returns Failure' do
        result = client_without_token.create_campaign(**valid_params)
        expect(result).to be_failure
        expect(result.failure[:error]).to include('Missing access token')
      end
    end

    context 'when Facebook API returns an error', vcr: { cassette_name: 'facebook_create_campaign_fail' } do
      it 'returns Failure with error details' do
        result = client.create_campaign(name: '', objective: 'INVALID', budget: -1)

        expect(result).to be_failure
        expect(result.failure[:error]).to include('Invalid parameter')
      end
    end
  end

  describe '#update_campaign' do
    context 'when access_token is missing' do
      let(:client_without_token) { described_class.new(account_id: account_id) }

      it 'returns Failure' do
        result = client_without_token.update_campaign(campaign_id: '120252481465730228', budget: 7500)
        expect(result).to be_failure
        expect(result.failure[:error]).to include('Missing access token')
      end
    end

    context 'when update is successful', vcr: { cassette_name: 'facebook_update_campaign_success' } do
      it 'updates campaign budget via SDK and returns Success' do
        result = client.update_campaign(campaign_id: '120252481465730228', budget: 7500)

        expect(result).to be_success
        expect(result.value![:success]).to be true
      end

      it 'updates campaign fields when budget is omitted' do
        result = client.update_campaign(campaign_id: '120252481465730228', status: 'ACTIVE')
        expect(result).to be_success
        expect(result.value![:success]).to be true
      end
    end

    context 'when Facebook API returns an error', vcr: { cassette_name: 'facebook_update_campaign_fail' } do
      it 'returns Failure with error details' do
        result = client.update_campaign(campaign_id: 'invalid_campaign_id', budget: -100)

        expect(result).to be_failure
        expect(result.failure[:error]).to include('Unsupported post request')
      end
    end

    context 'when Facebook returns non-JSON error', vcr: { cassette_name: 'facebook_update_campaign_fail' } do
      it 'returns Failure with HTTP error message' do
        result = client.update_campaign(campaign_id: 'server_error_campaign_id', budget: 7500)
        expect(result).to be_failure
        expect(result.failure[:error]).to eq('HTTP 500 Error')
      end
    end
  end

  describe '#fetch_campaign' do
    context 'when access_token is missing' do
      let(:client_without_token) { described_class.new(account_id: account_id) }

      it 'returns Failure' do
        result = client_without_token.fetch_campaign(campaign_id: '120252481465730228')
        expect(result).to be_failure
        expect(result.failure[:error]).to include('Missing access token')
      end
    end

    context 'when campaign exists', vcr: { cassette_name: 'facebook_fetch_campaign_success' } do
      it 'fetches campaign details via SDK and returns Success' do
        result = client.fetch_campaign(campaign_id: '120252481465730228')

        expect(result).to be_success
        data = result.value!
        expect(data[:id]).to eq('120252481465730228')
        expect(data[:name]).to eq('Summer Promo 2026')
        expect(data[:objective]).to eq('OUTCOME_TRAFFIC')
        expect(data[:status]).to eq('PAUSED')
      end
    end

    context 'when campaign does not exist', vcr: { cassette_name: 'facebook_fetch_campaign_fail' } do
      it 'returns Failure with error details' do
        result = client.fetch_campaign(campaign_id: 'non_existent_campaign')

        expect(result).to be_failure
        expect(result.failure[:error]).to include('does not exist')
      end
    end

    context 'when Facebook returns non-JSON error', vcr: { cassette_name: 'facebook_fetch_campaign_fail' } do
      it 'returns Failure with HTTP error message' do
        result = client.fetch_campaign(campaign_id: 'gateway_error_campaign_id')
        expect(result).to be_failure
        expect(result.failure[:error]).to eq('HTTP 502 Error')
      end
    end
  end
end

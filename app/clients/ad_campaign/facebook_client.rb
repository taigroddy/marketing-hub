# frozen_string_literal: true

require "facebookbusiness"
require "dry/monads"

module AdCampaign
  class FacebookClient < BaseClient
    include Dry::Monads[:result]

    API_VERSION = "v21.0"
    DEFAULT_FETCH_FIELDS = "id,name,objective,status,daily_budget,lifetime_budget"

    attr_reader :access_token, :account_id

    def initialize(access_token: nil, account_id: nil, **options)
      super()
      @access_token = access_token || options[:token]
      @account_id = account_id
    end

    def create_campaign(name:, objective:, budget: nil, account_id: nil, access_token: nil, status: "PAUSED", **extra_params)
      target_account = account_id || @account_id
      raise ArgumentError, "Missing required account_id" if target_account.blank?

      token = access_token || @access_token
      return Failure(error: "Missing access token") if token.blank?

      act_id = target_account.to_s.start_with?("act_") ? target_account.to_s : "act_#{target_account}"

      begin
        session = create_session(token)
        ad_account = FacebookAds::AdAccount.get(act_id, session)

        payload = {
          name: name,
          objective: objective,
          status: status || "PAUSED",
          special_ad_categories: extra_params[:special_ad_categories] || [ "NONE" ]
        }
        payload[:daily_budget] = extra_params[:daily_budget] || budget if budget || extra_params[:daily_budget]
        payload.merge!(extra_params.except(:special_ad_categories, :daily_budget))

        campaign = ad_account.campaigns.create(payload)
        raw_data = campaign.respond_to?(:to_hash) ? campaign.to_hash : { id: campaign.id }
        Success(id: campaign.id, raw: raw_data)
      rescue StandardError => e
        handle_error(e)
      end
    end

    def update_campaign(campaign_id:, budget: nil, access_token: nil, **params)
      token = access_token || @access_token
      return Failure(error: "Missing access token") if token.blank?

      begin
        session = create_session(token)
        campaign = FacebookAds::Campaign.get(campaign_id, session)

        payload = params.dup
        payload[:daily_budget] = budget if budget && !payload.key?(:daily_budget)

        response = campaign.post(payload)
        body = response.is_a?(FacebookAds::APIResponse) ? response.result : response
        success_flag = body.is_a?(Hash) ? body["success"] != false : true
        Success(id: campaign_id, success: success_flag, raw: body)
      rescue StandardError => e
        handle_error(e)
      end
    end

    def fetch_campaign(campaign_id:, fields: nil, access_token: nil)
      token = access_token || @access_token
      return Failure(error: "Missing access token") if token.blank?

      begin
        session = create_session(token)
        campaign = FacebookAds::Campaign.get(campaign_id, session)
        target_fields = fields || DEFAULT_FETCH_FIELDS

        response = campaign.get(fields: target_fields)
        body = response.is_a?(FacebookAds::APIResponse) ? response.result : response
        if body.is_a?(Hash)
          Success(body.transform_keys(&:to_sym))
        else
          Success(id: campaign_id, raw: body)
        end
      rescue StandardError => e
        handle_error(e)
      end
    end

    private

    def create_session(token)
      FacebookAds::Session.new(access_token: token, api_version: API_VERSION)
    end

    def handle_error(error)
      if error.is_a?(FacebookAds::APIError)
        api_resp = error.instance_variable_get(:@api_response)
        body = extract_error_body(error, api_resp)
        status_code = api_resp&.status_code
        error_msg = (body.is_a?(Hash) && body.dig("error", "message")) || (status_code ? "HTTP #{status_code} Error" : error.message)
        Failure(error: error_msg, details: body)
      else
        Failure(error: error.message)
      end
    end

    def extract_error_body(error, api_resp)
      if api_resp&.result.is_a?(Hash)
        api_resp.result
      else
        begin
          JSON.parse(error.message)
        rescue JSON::ParserError
          { "raw_body" => error.message }
        end
      end
    end
  end
end

module Clients
  module AdCampaign
    FacebookClient = ::AdCampaign::FacebookClient
  end
end

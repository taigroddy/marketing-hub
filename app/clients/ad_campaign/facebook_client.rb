# frozen_string_literal: true

require "net/http"
require "json"
require "uri"
require "dry/monads"

module AdCampaign
  class FacebookClient < BaseClient
    include Dry::Monads[:result]

    API_VERSION = "v21.0"
    GRAPH_API_BASE_URL = "https://graph.facebook.com/#{API_VERSION}"
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
      uri = URI.parse("#{GRAPH_API_BASE_URL}/#{act_id}/campaigns")

      payload = {
        name: name,
        objective: objective,
        status: status || "PAUSED",
        special_ad_categories: extra_params[:special_ad_categories] || [ "NONE" ]
      }
      payload[:daily_budget] = extra_params[:daily_budget] || budget if budget || extra_params[:daily_budget]
      payload.merge!(extra_params.except(:special_ad_categories, :daily_budget))

      perform_post(uri, payload, token) do |body|
        Success(id: body["id"], raw: body)
      end
    end

    def update_campaign(campaign_id:, budget: nil, access_token: nil, **params)
      token = access_token || @access_token
      return Failure(error: "Missing access token") if token.blank?

      uri = URI.parse("#{GRAPH_API_BASE_URL}/#{campaign_id}")

      payload = params.dup
      payload[:daily_budget] = budget if budget && !payload.key?(:daily_budget)

      perform_post(uri, payload, token) do |body|
        Success(id: campaign_id, success: body["success"] != false, raw: body)
      end
    end

    def fetch_campaign(campaign_id:, fields: nil, access_token: nil)
      token = access_token || @access_token
      return Failure(error: "Missing access token") if token.blank?

      target_fields = fields || DEFAULT_FETCH_FIELDS
      uri = URI.parse("#{GRAPH_API_BASE_URL}/#{campaign_id}")
      uri.query = URI.encode_www_form(fields: target_fields)

      perform_get(uri, token)
    end

    private

    def perform_post(uri, payload, token, &block)
      req = Net::HTTP::Post.new(uri)
      req["Accept"] = "application/json"
      req["Content-Type"] = "application/json"
      req["Authorization"] = "Bearer #{token}"
      req.body = JSON.generate(payload)

      res = execute_http_request(uri, req)
      parse_response(res, &block)
    rescue StandardError => e
      Failure(error: e.message)
    end

    def perform_get(uri, token)
      req = Net::HTTP::Get.new(uri)
      req["Accept"] = "application/json"
      req["Authorization"] = "Bearer #{token}"

      res = execute_http_request(uri, req)
      parse_response(res)
    rescue StandardError => e
      Failure(error: e.message)
    end

    def execute_http_request(uri, req)
      Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https") do |http|
        http.open_timeout = 10
        http.read_timeout = 10
        http.request(req)
      end
    end

    def parse_response(res)
      body = begin
        JSON.parse(res.body)
      rescue JSON::ParserError
        { "raw_body" => res.body }
      end

      if res.is_a?(Net::HTTPSuccess) && !body.key?("error")
        block_given? ? yield(body) : Success(body.transform_keys(&:to_sym))
      else
        error_msg = body.dig("error", "message") || "HTTP #{res.code} Error"
        Failure(error: error_msg, details: body)
      end
    end
  end
end

module Clients
  module AdCampaign
    FacebookClient = ::AdCampaign::FacebookClient
  end
end

# frozen_string_literal: true

require "net/http"
require "json"
require "uri"
require "dry/monads"

module OAuth
  class FacebookClient < BaseClient
    include Dry::Monads[:result]

    API_VERSION = "v21.0"
    OAUTH_DIALOG_URL = "https://www.facebook.com/#{API_VERSION}/dialog/oauth"
    GRAPH_API_BASE_URL = "https://graph.facebook.com/#{API_VERSION}"

    DEFAULT_SCOPES = "email,ads_management,ads_read"

    attr_reader :app_id, :app_secret, :redirect_uri

    def initialize(app_id: nil, app_secret: nil, redirect_uri: nil)
      super()
      @app_id = app_id || ENV["FB_APP_ID"]
      @app_secret = app_secret || ENV["FB_APP_SECRET"]
      @redirect_uri = redirect_uri || ENV["FB_AUTHORIZE_REDIRECT_URI"].presence || ENV["FB_AUTHORIZE_REDIRECT_UI"]
    end

    def authorize_url(state: nil, redirect_uri: nil, scope: nil)
      target_redirect_uri = redirect_uri || @redirect_uri
      target_scope = scope || DEFAULT_SCOPES

      params = {
        client_id: @app_id,
        redirect_uri: target_redirect_uri,
        response_type: "code",
        scope: target_scope
      }
      params[:state] = state if state.present?

      uri = URI.parse(OAUTH_DIALOG_URL)
      uri.query = URI.encode_www_form(params)
      uri.to_s
    end

    def exchange_code(arg_code = nil, code: nil, redirect_uri: nil)
      auth_code = arg_code || code
      raise ArgumentError, "Missing required argument: code" if auth_code.blank?

      target_redirect_uri = redirect_uri || @redirect_uri

      uri = URI.parse("#{GRAPH_API_BASE_URL}/oauth/access_token")
      uri.query = URI.encode_www_form({
        client_id: @app_id,
        client_secret: @app_secret,
        redirect_uri: target_redirect_uri,
        code: auth_code
      })

      perform_get(uri)
    end

    def refresh_token(arg_token = nil, refresh_token: nil, token: nil)
      target_token = arg_token || refresh_token || token
      raise ArgumentError, "Missing required argument: token" if target_token.blank?

      uri = URI.parse("#{GRAPH_API_BASE_URL}/oauth/access_token")
      uri.query = URI.encode_www_form({
        grant_type: "fb_exchange_token",
        client_id: @app_id,
        client_secret: @app_secret,
        fb_exchange_token: target_token
      })

      perform_get(uri)
    end

    def fetch_user_info(access_token)
      raise ArgumentError, "Missing required argument: access_token" if access_token.blank?

      uri = URI.parse("#{GRAPH_API_BASE_URL}/me")
      uri.query = URI.encode_www_form({
        access_token: access_token,
        fields: "id,name"
      })

      perform_get(uri)
    end

    def fetch_ad_accounts(access_token)
      raise ArgumentError, "Missing required argument: access_token" if access_token.blank?

      uri = URI.parse("#{GRAPH_API_BASE_URL}/me/adaccounts")
      uri.query = URI.encode_www_form({
        access_token: access_token,
        fields: "id,name,account_id"
      })

      perform_get(uri)
    end

    private

    def perform_get(uri)
      req = Net::HTTP::Get.new(uri)
      req["Accept"] = "application/json"

      res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https") do |http|
        http.open_timeout = 10
        http.read_timeout = 10
        http.request(req)
      end

      parse_response(res)
    rescue StandardError => e
      Failure(error: e.message)
    end

    def parse_response(res)
      body = begin
        JSON.parse(res.body)
      rescue JSON::ParserError
        { "raw_body" => res.body }
      end

      if res.is_a?(Net::HTTPSuccess) && !body.key?("error")
        Success(body.transform_keys(&:to_sym))
      else
        error_msg = body.dig("error", "message") || "HTTP #{res.code} Error"
        Failure(error: error_msg, details: body)
      end
    end
  end
end

module Clients
  module OAuth
    FacebookClient = ::OAuth::FacebookClient
  end
end

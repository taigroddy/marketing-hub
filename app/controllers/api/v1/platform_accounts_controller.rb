# frozen_string_literal: true

module Api
  module V1
    class PlatformAccountsController < ApplicationController
      skip_before_action :verify_authenticity_token, raise: false
      skip_before_action :allow_browser, raise: false
      before_action :authenticate_user!

      def index
        accounts = Current.user.platform_accounts.order(created_at: :desc)
        render json: { platform_accounts: PlatformAccountBlueprint.render_as_hash(accounts) }, status: :ok
      end

      def authorize
        platform = params[:platform].to_s.downcase

        case platform
        when "facebook"
          client = Clients::OAuth::FacebookClient.new
          auth_url = client.authorize_url(
            state: params[:state],
            redirect_uri: params[:redirect_uri],
            scope: params[:scope]
          )

          if html_browser_request?
            redirect_to auth_url, allow_other_host: true
          else
            render json: { authorize_url: auth_url }, status: :ok
          end
        when "google"
          render json: { error: "Google platform integration coming soon" }, status: :not_implemented
        else
          render json: { error: "Unsupported platform: #{platform}" }, status: :bad_request
        end
      end

      def callback
        PlatformAccounts::ConnectService.call(full_request_params) do |m|
          m.success do |result|
            if html_browser_request?
              redirect_to dashboard_path, notice: "Tài khoản #{result[:platform_account].platform_name} đã được kết nối thành công."
            else
              render json: {
                platform_account: PlatformAccountBlueprint.render_as_hash(result[:platform_account]),
                message: "Platform account connected successfully"
              }, status: :ok
            end
          end

          m.failure(:validation) do |errors|
            if html_browser_request?
              redirect_to dashboard_path, alert: "Kết nối thất bại: #{errors.values.flatten.join(', ')}"
            else
              render json: { errors: errors }, status: :unprocessable_entity
            end
          end

          m.failure do |error|
            error_msg = error.is_a?(Hash) ? (error[:error] || error.values.flatten.join(", ")) : error.to_s
            if html_browser_request?
              redirect_to dashboard_path, alert: "Kết nối thất bại: #{error_msg}"
            else
              render json: { error: error_msg }, status: :unprocessable_entity
            end
          end
        end
      end

      private

      def html_browser_request?
        request.format.html? && params[:format] != "json"
      end
    end
  end
end

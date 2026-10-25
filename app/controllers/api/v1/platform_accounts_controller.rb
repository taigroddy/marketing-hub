# frozen_string_literal: true

module Api
  module V1
    class PlatformAccountsController < ApplicationController
      skip_before_action :verify_authenticity_token, raise: false
      skip_before_action :allow_browser, raise: false
      before_action :authenticate_user!

      def index
        accounts = Current.user.platform_accounts.order(created_at: :desc)
        render json: {
          success: true,
          data: { platform_accounts: PlatformAccountBlueprint.render_as_hash(accounts) },
          errors: nil
        }, status: :ok
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

          render json: {
            success: true,
            data: { authorize_url: auth_url },
            errors: nil
          }, status: :ok
        when "google"
          render json: { success: false, data: nil, errors: "Google platform integration coming soon" }, status: :not_implemented
        else
          render json: { success: false, data: nil, errors: "Unsupported platform: #{platform}" }, status: :bad_request
        end
      end

      def callback
        PlatformAccounts::ConnectService.call(full_request_params) do |m|
          m.success do |result|
            if request.format.json?
              render json: {
                success: true,
                data: {
                  platform_account: PlatformAccountBlueprint.render_as_hash(result[:platform_account]),
                  message: "Platform account connected successfully"
                },
                errors: nil
              }, status: :ok
            else
              redirect_to dashboard_path, notice: "Tài khoản #{result[:platform_account].platform_name} đã được kết nối thành công."
            end
          end

          m.failure(:validation) do |errors|
            if request.format.json?
              render json: { success: false, data: nil, errors: errors }, status: :unprocessable_content
            else
              redirect_to dashboard_path, alert: "Kết nối thất bại: #{errors.values.flatten.join(', ')}"
            end
          end

          m.failure(:check_resource) do |_error|
            if request.format.json?
              render json: { success: false, data: nil, errors: "Unauthorized" }, status: :unauthorized
            else
              redirect_to dashboard_path, alert: "Kết nối thất bại: Unauthorized"
            end
          end

          m.failure do |error|
            error_msg = extract_error_message(error)
            if request.format.json?
              render json: { success: false, data: nil, errors: error_msg }, status: :unprocessable_content
            else
              redirect_to dashboard_path, alert: "Kết nối thất bại: #{error_msg}"
            end
          end
        end
      end

      private

      def render_unauthorized(message = "Unauthorized")
        render json: { success: false, data: nil, errors: message }, status: :unauthorized
      end

      def extract_error_message(error)
        if error.is_a?(Hash)
          error[:error] || error.values.flatten.join(", ")
        else
          error.to_s
        end
      end
    end
  end
end

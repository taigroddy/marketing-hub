# frozen_string_literal: true

module Api
  module V1
    class PlatformAccountsController < ApplicationController
      skip_before_action :verify_authenticity_token, raise: false
      skip_before_action :allow_browser, raise: false
      before_action :authenticate_user!

      rescue_from NameError, NotImplementedError, with: :handle_platform_error

      def index
        accounts = PlatformAccount.order(created_at: :desc)
        render json: {
          success: true,
          data: { platform_accounts: PlatformAccountBlueprint.render_as_hash(accounts) },
          errors: nil
        }, status: :ok
      end

      def authorize
        client_class = "Clients::OAuth::#{params[:platform].to_s.classify}Client".constantize
        client = client_class.new
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

      def handle_platform_error(exception)
        error_msg = exception.message.presence || "Platform not supported"
        if request.format.json?
          render json: {
            success: false,
            data: nil,
            errors: error_msg
          }, status: :not_found
        else
          redirect_to dashboard_path, alert: "Kết nối thất bại: #{error_msg}"
        end
      end

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

# frozen_string_literal: true

module Api
  module V1
    class PlatformAccountsController < Api::BaseController
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
        state = params[:state].presence || (Current.user ? Authenticable.encode_jwt({ user_id: Current.user.id, purpose: "oauth_state" }, 15.minutes.from_now) : nil)
        auth_url = client.authorize_url(
          state: state,
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
                  message: I18n.t("platform_accounts.messages.connected")
                },
                errors: nil
              }, status: :ok
            else
              redirect_to dashboard_path, notice: I18n.t("platform_accounts.messages.connected_notice", name: result[:platform_account].platform_name)
            end
          end

          m.failure(:validation) do |errors|
            if request.format.json?
              render json: { success: false, data: nil, errors: errors }, status: :unprocessable_content
            else
              redirect_to dashboard_path, alert: I18n.t("platform_accounts.messages.connect_failed", error: errors.values.flatten.join(", "))
            end
          end

          m.failure do |error|
            error_msg = error.is_a?(Hash) ? (error[:error] || error.values.flatten.join(", ")) : error.to_s
            if request.format.json?
              render json: { success: false, data: nil, errors: error_msg }, status: :unprocessable_content
            else
              redirect_to dashboard_path, alert: I18n.t("platform_accounts.messages.connect_failed", error: error_msg)
            end
          end
        end
      end

      private

      def render_token_unauthorized(message = nil)
        if request.format.html?
          redirect_to dashboard_path, alert: I18n.t("platform_accounts.messages.unauthorized", default: "Phiên làm việc không hợp lệ hoặc đã hết hạn.")
        else
          super
        end
      end

      def handle_platform_error(exception)
        error_msg = exception.message.presence || I18n.t("platform_accounts.messages.not_supported")
        if request.format.json?
          render json: {
            success: false,
            data: nil,
            errors: error_msg
          }, status: :not_found
        else
          redirect_to dashboard_path, alert: I18n.t("platform_accounts.messages.connect_failed", error: error_msg)
        end
      end
    end
  end
end

# frozen_string_literal: true

module Api
  module V1
    class AuthController < Api::BaseController
      before_action :authenticate_user!, only: [ :me ]

      def register
        Auth::RegisterService.call(full_request_params) do |m|
          m.success do |data|
            render json: {
              success: true,
              data: {
                message: I18n.t("auth.registration_success"),
                user: UserBlueprint.render_as_hash(data[:user])
              },
              errors: nil
            }, status: :created
          end

          m.failure(:validation) do |errors|
            render json: { success: false, data: nil, errors: errors }, status: :unprocessable_entity
          end

          m.failure do |error|
            render json: { success: false, data: nil, errors: error }, status: :unprocessable_entity
          end
        end
      end

      def login
        params_with_device = full_request_params.merge(device_info: request.user_agent)
        Auth::LoginService.call(params_with_device) do |m|
          m.success do |data|
            render json: {
              success: true,
              data: {
                token: data[:token],
                refresh_token: data[:refresh_token],
                user: UserBlueprint.render_as_hash(data[:user])
              },
              errors: nil
            }, status: :ok
          end

          m.failure(:validation) do |errors|
            render json: { success: false, data: nil, errors: errors }, status: :unprocessable_entity
          end

          m.failure do |error|
            handle_login_failure(error)
          end
        end
      end

      def refresh
        params_with_device = full_request_params.merge(device_info: request.user_agent)
        Auth::RefreshTokenService.call(params_with_device) do |m|
          m.success do |data|
            render json: {
              success: true,
              data: {
                token: data[:token],
                refresh_token: data[:refresh_token],
                user: UserBlueprint.render_as_hash(data[:user])
              },
              errors: nil
            }, status: :ok
          end

          m.failure(:validation) do |errors|
            render json: { success: false, data: nil, errors: errors }, status: :unprocessable_entity
          end

          m.failure do |_error|
            render json: { success: false, data: nil, errors: I18n.t("auth.invalid_refresh_token") }, status: :unauthorized
          end
        end
      end

      def logout
        logout_params = full_request_params
        if logout_params[:refresh_token].blank? && current_user_token_id.present?
          logout_params = logout_params.merge(user_token_id: current_user_token_id)
        end

        Auth::LogoutService.call(logout_params) do |m|
          m.success do |_data|
            render json: {
              success: true,
              data: { message: I18n.t("auth.logout_success") },
              errors: nil
            }, status: :ok
          end

          m.failure(:validation) do |errors|
            render json: { success: false, data: nil, errors: errors }, status: :unprocessable_entity
          end

          m.failure do |_error|
            render json: { success: false, data: nil, errors: I18n.t("auth.invalid_token") }, status: :unauthorized
          end
        end
      end

      def confirm_email
        Auth::ConfirmEmailService.call(full_request_params) do |m|
          m.success do |data|
            render json: {
              success: true,
              data: {
                token: data[:token],
                user: UserBlueprint.render_as_hash(data[:user]),
                message: I18n.t("auth.email_confirmed")
              },
              errors: nil
            }, status: :ok
          end

          m.failure(:validation) do |_errors|
            render json: { success: false, data: nil, errors: I18n.t("auth.invalid_confirmation_token") }, status: :unprocessable_entity
          end

          m.failure do |_error|
            render json: { success: false, data: nil, errors: I18n.t("auth.invalid_confirmation_token") }, status: :unprocessable_entity
          end
        end
      end

      def me
        render json: {
          success: true,
          data: { user: UserBlueprint.render_as_hash(current_user) },
          errors: nil
        }, status: :ok
      end

      private

      def handle_login_failure(failure)
        case failure
        when :unconfirmed_email
          render json: { success: false, data: nil, errors: I18n.t("auth.unconfirmed_email") }, status: :forbidden
        when :invalid_credentials
          render json: { success: false, data: nil, errors: I18n.t("auth.invalid_credentials") }, status: :unauthorized
        else
          render json: { success: false, data: nil, errors: failure }, status: :unprocessable_entity
        end
      end
    end
  end
end

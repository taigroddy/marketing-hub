# frozen_string_literal: true

module Api
  module V1
    class AuthController < ApplicationController
      skip_before_action :verify_authenticity_token, raise: false
      skip_before_action :allow_browser, raise: false
      before_action :authenticate_user!, only: [ :me ]

      def register
        Auth::RegisterService.call(full_request_params) do |m|
          m.success do |data|
            render json: {
              message: "Registration successful. Please check your email to confirm your account.",
              user: UserBlueprint.render_as_hash(data[:user])
            }, status: :created
          end

          m.failure(:validation) do |errors|
            render json: { errors: errors }, status: :unprocessable_entity
          end

          m.failure do |error|
            render json: { errors: error }, status: :unprocessable_entity
          end
        end
      end

      def login
        params_with_device = full_request_params.merge(device_info: request.user_agent)
        Auth::LoginService.call(params_with_device) do |m|
          m.success do |data|
            render json: {
              token: data[:token],
              refresh_token: data[:refresh_token],
              user: UserBlueprint.render_as_hash(data[:user])
            }, status: :ok
          end

          m.failure(:validation) do |errors|
            render json: { errors: errors }, status: :unprocessable_entity
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
              token: data[:token],
              refresh_token: data[:refresh_token],
              user: UserBlueprint.render_as_hash(data[:user])
            }, status: :ok
          end

          m.failure(:validation) do |errors|
            render json: { errors: errors }, status: :unprocessable_entity
          end

          m.failure do |_error|
            render json: { error: "Invalid or expired refresh token." }, status: :unauthorized
          end
        end
      end

      def logout
        Auth::LogoutService.call(full_request_params) do |m|
          m.success do |_data|
            render json: { message: "Logged out successfully." }, status: :ok
          end

          m.failure(:validation) do |errors|
            render json: { errors: errors }, status: :unprocessable_entity
          end

          m.failure do |_error|
            render json: { error: "Invalid or expired refresh token." }, status: :unauthorized
          end
        end
      end

      def confirm_email
        Auth::ConfirmEmailService.call(full_request_params) do |m|
          m.success do |data|
            render json: {
              token: data[:token],
              user: UserBlueprint.render_as_hash(data[:user]),
              message: "Email confirmed successfully."
            }, status: :ok
          end

          m.failure(:validation) do |_errors|
            render json: { error: "Invalid or expired confirmation token." }, status: :unprocessable_entity
          end

          m.failure do |_error|
            render json: { error: "Invalid or expired confirmation token." }, status: :unprocessable_entity
          end
        end
      end

      def me
        render json: { user: UserBlueprint.render_as_hash(current_user) }, status: :ok
      end

      private

      def handle_login_failure(failure)
        case failure
        when :unconfirmed_email
          render json: { error: "Please confirm your email address before logging in." }, status: :forbidden
        when :invalid_credentials
          render json: { error: "Invalid email or password." }, status: :unauthorized
        else
          render json: { errors: failure }, status: :unprocessable_entity
        end
      end
    end
  end
end

# frozen_string_literal: true

module Api
  module V1
    class AuthController < ApplicationController
      skip_before_action :verify_authenticity_token, raise: false
      skip_before_action :allow_browser, raise: false
      before_action :authenticate_user!, only: [ :me ]

      def register
        result = Auth::RegisterService.call(register_params)
        if result.success?
          user = result.value![:user]
          render json: {
            message: "Registration successful. Please check your email to confirm your account.",
            user: UserBlueprint.render_as_hash(user)
          }, status: :created
        else
          render json: { errors: result.failure }, status: :unprocessable_entity
        end
      end

      def login
        result = Auth::LoginService.call(login_params)
        if result.success?
          data = result.value!
          render json: {
            token: data[:token],
            user: UserBlueprint.render_as_hash(data[:user])
          }, status: :ok
        else
          handle_login_failure(result.failure)
        end
      end

      def confirm_email
        result = Auth::ConfirmEmailService.call(token: params[:token])
        if result.success?
          data = result.value!
          render json: {
            token: data[:token],
            user: UserBlueprint.render_as_hash(data[:user]),
            message: "Email confirmed successfully."
          }, status: :ok
        else
          render json: { error: "Invalid or expired confirmation token." }, status: :unprocessable_entity
        end
      end

      def me
        render json: { user: UserBlueprint.render_as_hash(current_user) }, status: :ok
      end

      private

      def register_params
        params.permit(:email, :password, :password_confirmation)
      end

      def login_params
        params.permit(:email, :password)
      end

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

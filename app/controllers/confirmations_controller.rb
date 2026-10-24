# frozen_string_literal: true

class ConfirmationsController < ApplicationController
  def show
    Auth::ConfirmEmailService.call(params) do |m|
      m.success do |data|
        cookies[:jwt_token] = {
          value: data[:token],
          httponly: true,
          same_site: :lax
        }
        redirect_to dashboard_path, notice: "Your email has been confirmed successfully!"
      end

      m.failure(:validation) do |_errors|
        redirect_to login_path, alert: "Invalid or expired confirmation link."
      end

      m.failure do |_error|
        redirect_to login_path, alert: "Invalid or expired confirmation link."
      end
    end
  end
end

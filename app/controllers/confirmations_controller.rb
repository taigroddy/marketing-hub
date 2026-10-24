# frozen_string_literal: true

class ConfirmationsController < ApplicationController
  def show
    result = Auth::ConfirmEmailService.call(token: params[:token])

    if result.success?
      cookies[:jwt_token] = {
        value: result.value![:token],
        httponly: true,
        same_site: :lax
      }
      redirect_to dashboard_path, notice: "Your email has been confirmed successfully!"
    else
      redirect_to login_path, alert: "Invalid or expired confirmation link."
    end
  end
end

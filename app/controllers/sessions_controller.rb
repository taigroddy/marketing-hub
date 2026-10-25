# frozen_string_literal: true

class SessionsController < ApplicationController
  def new
    redirect_to dashboard_path if current_user
  end

  def destroy
    refresh_token = cookies[:refresh_token] || cookies["refresh_token"]
    Auth::LogoutService.call(refresh_token: refresh_token) if refresh_token.present?

    cookies.delete(:jwt_token, secure: Rails.env.production?, same_site: :lax)
    cookies.delete(:refresh_token, secure: Rails.env.production?, same_site: :lax)
    redirect_to login_path, notice: "Logged out successfully."
  end
end

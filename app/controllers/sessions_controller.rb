# frozen_string_literal: true

class SessionsController < ApplicationController
  def new
    redirect_to dashboard_path if current_user
  end

  def create
    Auth::LoginService.call(params) do |m|
      m.success do |data|
        cookies[:jwt_token] = {
          value: data[:token],
          httponly: true,
          same_site: :lax
        }
        redirect_to dashboard_path, notice: "Logged in successfully."
      end

      m.failure(:validation) do |_errors|
        flash.now[:alert] = "Please enter a valid email and password."
        render :new, status: :unprocessable_entity
      end

      m.failure do |error|
        handle_login_failure(error)
        render :new, status: :unprocessable_entity
      end
    end
  end

  def destroy
    cookies.delete(:jwt_token)
    redirect_to login_path, notice: "Logged out successfully."
  end

  private

  def handle_login_failure(failure)
    flash.now[:alert] = case failure
    when :unconfirmed_email
                          "Please confirm your email address before logging in."
    when :invalid_credentials
                          "Invalid email or password."
    else
                          "Please enter a valid email and password."
    end
  end
end

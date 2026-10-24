# frozen_string_literal: true

class SessionsController < ApplicationController
  def new
    redirect_to dashboard_path if current_user
  end

  def create
    result = Auth::LoginService.call(login_params)

    if result.success?
      cookies[:jwt_token] = {
        value: result.value![:token],
        httponly: true,
        same_site: :lax
      }
      redirect_to dashboard_path, notice: "Logged in successfully."
    else
      handle_login_failure(result.failure)
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    cookies.delete(:jwt_token)
    redirect_to login_path, notice: "Logged out successfully."
  end

  private

  def login_params
    params.permit(:email, :password)
  end

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

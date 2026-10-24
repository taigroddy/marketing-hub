# frozen_string_literal: true

class RegistrationsController < ApplicationController
  def new
    redirect_to dashboard_path if current_user
  end

  def create
    result = Auth::RegisterService.call(registration_params)

    if result.success?
      redirect_to login_path, notice: "Registration successful! Please check your email to confirm your account."
    else
      @errors = result.failure
      flash.now[:alert] = "Registration failed. Please correct the errors below."
      render :new, status: :unprocessable_entity
    end
  end

  private

  def registration_params
    params.permit(:email, :password, :password_confirmation)
  end
end

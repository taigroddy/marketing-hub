# frozen_string_literal: true

class RegistrationsController < ApplicationController
  def new
    redirect_to dashboard_path if current_user
  end

  def create
    Auth::RegisterService.call(params) do |m|
      m.success do |_data|
        redirect_to login_path, notice: "Registration successful! Please check your email to confirm your account."
      end

      m.failure(:validation) do |errors|
        @errors = errors
        flash.now[:alert] = "Registration failed. Please correct the errors below."
        render :new, status: :unprocessable_entity
      end

      m.failure do |error|
        @errors = error
        flash.now[:alert] = "Registration failed. Please correct the errors below."
        render :new, status: :unprocessable_entity
      end
    end
  end
end

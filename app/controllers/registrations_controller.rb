# frozen_string_literal: true

class RegistrationsController < ApplicationController
  def new
    redirect_to dashboard_path if current_user
  end
end

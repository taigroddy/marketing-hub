# frozen_string_literal: true

class SessionsController < ApplicationController
  def new
    if params[:logout].present?
      clear_session_cookies
      Current.user = nil
      return
    end

    redirect_to dashboard_path if current_user
  end
end

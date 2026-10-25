# frozen_string_literal: true

class DashboardController < ApplicationController
  before_action :authenticate_user!

  def index
    @platform_accounts = PlatformAccount.order(created_at: :desc)
    @campaigns = Campaign.order(created_at: :desc)
    render :index
  end
end

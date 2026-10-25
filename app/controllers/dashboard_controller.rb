# frozen_string_literal: true

class DashboardController < ApplicationController
  before_action :authenticate_user!

  def show
    @platform_accounts = PlatformAccount.order(created_at: :desc)
    @campaigns = Campaign.order(created_at: :desc)
  end

  def index
    show
    render :show
  end
end

# frozen_string_literal: true

class DashboardController < ApplicationController
  before_action :authenticate_user!

  def show
    @platform_accounts = Current.user.platform_accounts.order(created_at: :desc)
    @campaigns = Current.user.campaigns.order(created_at: :desc)
  end

  def index
    show
    render :show
  end
end

# frozen_string_literal: true

class DashboardController < ApplicationController
  before_action :authenticate_user!

  def show
    @campaigns = Current.user.campaigns.order(created_at: :desc)
  end

  def index
    show
    render :show
  end
end

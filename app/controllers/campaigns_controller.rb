# frozen_string_literal: true

class CampaignsController < ApplicationController
  before_action :authenticate_user!

  def index
    @campaigns = Campaign.order(created_at: :desc)
  end

  def show
    @campaign = Campaign.find_by(id: params[:id])
    if @campaign
      @platform_accounts = PlatformAccount.connected
      @platform_campaigns = @campaign.platform_campaigns.includes(:platform_account).order(created_at: :desc)
      @published_account_ids = @campaign.platform_campaigns.pluck(:platform_account_id)
      render :show
    else
      render_not_found
    end
  end

  def new
    @campaign = Campaign.new
  end

  def edit
    @campaign = Campaign.find_by(id: params[:id])
    if @campaign
      render :edit
    else
      render_not_found
    end
  end

  private

  def render_not_found
    render file: Rails.public_path.join("404.html"), status: :not_found, layout: false
  end
end

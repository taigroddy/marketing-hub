# frozen_string_literal: true

class CampaignsController < ApplicationController
  before_action :authenticate_user!

  def index
    @campaigns = Current.user.campaigns.order(created_at: :desc)
  end

  def show
    @campaign = Current.user.campaigns.find_by(id: params[:id])
    if @campaign
      @platform_accounts = Current.user.platform_accounts.connected
      @platform_campaigns = @campaign.platform_campaigns.includes(:platform_account).order(created_at: :desc)
      @published_account_ids = @campaign.platform_campaigns.pluck(:platform_account_id)
      render :show
    else
      render_not_found
    end
  end

  def new
    @campaign = Current.user.campaigns.new
  end

  def edit
    @campaign = Current.user.campaigns.find_by(id: params[:id])
    if @campaign
      render :edit
    else
      render_not_found
    end
  end

  def create
    Campaigns::CreateService.call(full_request_params) do |m|
      m.success do |_result|
        redirect_to dashboard_path, notice: "Campaign created successfully."
      end

      m.failure(:validation) do |errors|
        @campaign = Current.user.campaigns.new(campaign_attributes_from_params)
        @errors = errors
        flash.now[:alert] = "Please fix the errors below."
        render :new, status: :unprocessable_content
      end

      m.failure do |_error|
        @campaign = Current.user.campaigns.new(campaign_attributes_from_params)
        flash.now[:alert] = "Failed to create campaign."
        render :new, status: :unprocessable_content
      end
    end
  end

  def update
    Campaigns::UpdateBudgetService.call(full_request_params) do |m|
      m.success do |_result|
        redirect_to dashboard_path, notice: "Campaign budget updated successfully."
      end

      m.failure(:validation) do |errors|
        @campaign = Current.user.campaigns.find_by(id: params[:id])
        return render_not_found if @campaign.nil?

        @errors = errors
        flash.now[:alert] = "Please fix the errors below."
        render :edit, status: :unprocessable_content
      end

      m.failure(:check_resource) do |_error|
        render_not_found
      end

      m.failure do |_error|
        @campaign = Current.user.campaigns.find_by(id: params[:id])
        flash.now[:alert] = "Failed to update campaign budget."
        render :edit, status: :unprocessable_content
      end
    end
  end

  private

  def render_not_found
    render file: Rails.public_path.join("404.html"), status: :not_found, layout: false
  end

  def campaign_attributes_from_params
    nested = full_request_params[:campaign] || full_request_params["campaign"] || full_request_params
    nested = nested.to_unsafe_h if nested.respond_to?(:to_unsafe_h)
    nested = nested.symbolize_keys if nested.respond_to?(:symbolize_keys)
    {
      name: nested[:name],
      objective: nested[:objective],
      budget: nested[:budget]
    }
  end
end

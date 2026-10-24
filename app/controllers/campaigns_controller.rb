# frozen_string_literal: true

class CampaignsController < ApplicationController
  before_action :authenticate_user!

  def index
    @campaigns = Current.user.campaigns.order(created_at: :desc)
  end

  def show
    @campaign = Current.user.campaigns.find_by(id: params[:id])
    if @campaign
      render :show
    else
      redirect_to dashboard_path, alert: "Campaign not found"
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
      redirect_to dashboard_path, alert: "Campaign not found"
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
        render :new, status: :unprocessable_entity
      end

      m.failure do |error|
        @campaign = Current.user.campaigns.new(campaign_attributes_from_params)
        flash.now[:alert] = error.is_a?(String) ? error : "Failed to create campaign."
        render :new, status: :unprocessable_entity
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
        return redirect_to dashboard_path, alert: "Campaign not found." if @campaign.nil?

        @errors = errors
        flash.now[:alert] = "Please fix the errors below."
        render :edit, status: :unprocessable_entity
      end

      m.failure do |_error|
        redirect_to dashboard_path, alert: "Campaign not found."
      end
    end
  end

  private

  def campaign_attributes_from_params
    p = full_request_params
    nested = p[:campaign] || p["campaign"] || p
    {
      name: nested[:name] || nested["name"],
      objective: nested[:objective] || nested["objective"],
      budget: nested[:budget] || nested["budget"]
    }
  end
end

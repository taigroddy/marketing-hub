# frozen_string_literal: true

module Api
  module V1
    class CampaignsController < ApplicationController
      skip_before_action :verify_authenticity_token, raise: false
      skip_before_action :allow_browser, raise: false
      before_action :authenticate_user!

      def index
        campaigns = Current.user.campaigns.order(created_at: :desc)
        render json: { campaigns: CampaignBlueprint.render_as_hash(campaigns) }, status: :ok
      end

      def show
        campaign = Current.user.campaigns.find_by(id: params[:id])
        if campaign
          render json: { campaign: CampaignBlueprint.render_as_hash(campaign) }, status: :ok
        else
          render json: { error: "Campaign not found" }, status: :not_found
        end
      end

      def create
        Campaigns::CreateService.call(full_request_params) do |m|
          m.success do |result|
            render json: {
              campaign: CampaignBlueprint.render_as_hash(result[:campaign]),
              message: "Campaign created successfully"
            }, status: :created
          end

          m.failure(:validation) do |errors|
            render json: { errors: errors }, status: :unprocessable_content
          end

          m.failure(:check_resource) do |_error|
            render json: { error: "Unauthorized" }, status: :unauthorized
          end

          m.failure do |error|
            render json: { errors: error }, status: :unprocessable_content
          end
        end
      end

      def update
        Campaigns::UpdateBudgetService.call(full_request_params) do |m|
          m.success do |result|
            render json: {
              campaign: CampaignBlueprint.render_as_hash(result[:campaign]),
              message: "Campaign budget updated successfully"
            }, status: :ok
          end

          m.failure(:validation) do |errors|
            render json: { errors: errors }, status: :unprocessable_content
          end

          m.failure(:check_resource) do |_error|
            render json: { error: "Campaign not found" }, status: :not_found
          end

          m.failure do |error|
            render json: { errors: error }, status: :unprocessable_content
          end
        end
      end
    end
  end
end

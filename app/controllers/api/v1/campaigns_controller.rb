# frozen_string_literal: true

module Api
  module V1
    class CampaignsController < ApplicationController
      skip_before_action :verify_authenticity_token, raise: false
      skip_before_action :allow_browser, raise: false
      before_action :authenticate_user!

      def index
        campaigns = Campaign.order(created_at: :desc)
        render json: {
          success: true,
          data: { campaigns: CampaignBlueprint.render_as_hash(campaigns) },
          errors: nil
        }, status: :ok
      end

      def show
        campaign = Campaign.find_by(id: params[:id])
        if campaign
          render json: {
            success: true,
            data: { campaign: CampaignBlueprint.render_as_hash(campaign) },
            errors: nil
          }, status: :ok
        else
          render json: { success: false, data: nil, errors: "Campaign not found" }, status: :not_found
        end
      end

      def create
        Campaigns::CreateService.call(full_request_params) do |m|
          m.success do |result|
            render json: {
              success: true,
              data: {
                campaign: CampaignBlueprint.render_as_hash(result[:campaign]),
                message: "Campaign created successfully"
              },
              errors: nil
            }, status: :created
          end

          m.failure(:validation) do |errors|
            render json: { success: false, data: nil, errors: errors }, status: :unprocessable_content
          end

          m.failure(:check_resource) do |_error|
            render json: { success: false, data: nil, errors: "Unauthorized" }, status: :unauthorized
          end

          m.failure do |error|
            render json: { success: false, data: nil, errors: error }, status: :unprocessable_content
          end
        end
      end

      def update
        Campaigns::UpdateService.call(full_request_params) do |m|
          m.success do |result|
            render json: {
              success: true,
              data: {
                campaign: CampaignBlueprint.render_as_hash(result[:campaign]),
                message: "Campaign budget updated successfully"
              },
              errors: nil
            }, status: :ok
          end

          m.failure(:validation) do |errors|
            render json: { success: false, data: nil, errors: errors }, status: :unprocessable_content
          end

          m.failure(:check_resource) do |_error|
            render json: { success: false, data: nil, errors: "Campaign not found" }, status: :not_found
          end

          m.failure do |error|
            render json: { success: false, data: nil, errors: error }, status: :unprocessable_content
          end
        end
      end

      private

      def render_unauthorized(message = "Unauthorized")
        render json: { success: false, data: nil, errors: message }, status: :unauthorized
      end
    end
  end
end

# frozen_string_literal: true

module Api
  module V1
    class PlatformCampaignsController < ApplicationController
      skip_before_action :verify_authenticity_token, raise: false
      skip_before_action :allow_browser, raise: false
      before_action :authenticate_user!

      def publish
        PlatformCampaigns::PublishService.call(full_request_params) do |m|
          m.success do |result|
            if html_browser_request?
              redirect_to campaign_path(result[:campaign]), notice: "Chiến dịch đang được đồng bộ lên nền tảng."
            else
              render json: {
                platform_campaigns: PlatformCampaignBlueprint.render_as_hash(result[:platform_campaigns]),
                message: "Campaign publish initiated successfully"
              }, status: :ok
            end
          end

          m.failure(:validation) do |errors|
            if html_browser_request?
              redirect_to campaign_path(params[:id]), alert: "Đồng bộ thất bại: #{format_errors(errors)}"
            else
              render json: { errors: errors }, status: :unprocessable_entity
            end
          end

          m.failure do |error|
            error_msg = extract_error_message(error)
            if html_browser_request?
              redirect_to campaign_path(params[:id]), alert: "Đồng bộ thất bại: #{error_msg}"
            else
              render json: { error: error_msg }, status: :unprocessable_entity
            end
          end
        end
      end

      def resync
        PlatformCampaigns::ResyncService.call(full_request_params) do |m|
          m.success do |result|
            if html_browser_request?
              redirect_to campaign_path(result[:campaign]), notice: "Đã yêu cầu đồng bộ lại chiến dịch."
            else
              render json: {
                platform_campaigns: PlatformCampaignBlueprint.render_as_hash(result[:platform_campaigns]),
                message: "Campaign resync initiated successfully"
              }, status: :ok
            end
          end

          m.failure(:validation) do |errors|
            if html_browser_request?
              redirect_to campaign_path(params[:id]), alert: "Đồng bộ lại thất bại: #{format_errors(errors)}"
            else
              render json: { errors: errors }, status: :unprocessable_entity
            end
          end

          m.failure do |error|
            error_msg = extract_error_message(error)
            if html_browser_request?
              redirect_to campaign_path(params[:id]), alert: "Đồng bộ lại thất bại: #{error_msg}"
            else
              render json: { error: error_msg }, status: :unprocessable_entity
            end
          end
        end
      end

      private

      def html_browser_request?
        request.format.html? && params[:format] != "json"
      end

      def format_errors(errors)
        errors.is_a?(Hash) ? errors.values.flatten.join(", ") : errors.to_s
      end

      def extract_error_message(error)
        if error.is_a?(Hash)
          error[:error] || error.values.flatten.join(", ")
        else
          error.to_s
        end
      end
    end
  end
end

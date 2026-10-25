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
              render json: { errors: errors }, status: :unprocessable_content
            end
          end

          m.failure(:check_resource) do |error|
            render_publish_check_resource_failure(error)
          end

          m.failure do |error|
            render json: { error: extract_error_message(error) }, status: :unprocessable_content
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
              redirect_to dashboard_path, alert: "Đồng bộ lại thất bại: #{format_errors(errors)}"
            else
              render json: { errors: errors }, status: :unprocessable_content
            end
          end

          m.failure(:check_resource) do |error|
            render_resync_check_resource_failure(error)
          end

          m.failure(:detect_drift) do |error|
            error_msg = extract_error_message(error)
            if html_browser_request?
              redirect_to campaign_path(params[:id]), alert: "Đồng bộ lại thất bại: #{error_msg}"
            else
              render json: { error: error_msg }, status: :unprocessable_content
            end
          end

          m.failure do |error|
            render json: { error: extract_error_message(error) }, status: :unprocessable_content
          end
        end
      end

      private

      def render_publish_check_resource_failure(error)
        status, message = publish_check_resource_status_and_message(error)

        if html_browser_request?
          if status == :not_found && error.is_a?(Hash) && error[:campaign]
            render file: Rails.public_path.join("404.html"), status: :not_found, layout: false
          else
            redirect_to campaign_path(params[:id]), alert: "Đồng bộ thất bại: #{message}"
          end
        else
          render json: { error: message }, status: status
        end
      end

      def publish_check_resource_status_and_message(error)
        return [ :unauthorized, "Unauthorized" ] unless error.is_a?(Hash)

        if error[:campaign]
          [ :not_found, "Campaign not found" ]
        elsif error[:platform_accounts]
          [ :not_found, "Platform account not found" ]
        elsif error[:platform_account_ids]
          [ :conflict, "Already published for this campaign" ]
        elsif error[:error]
          [ :unprocessable_content, error[:error] ]
        else
          [ :unprocessable_content, extract_error_message(error) ]
        end
      end

      def render_resync_check_resource_failure(error)
        status, message = resync_check_resource_status_and_message(error)

        if html_browser_request?
          if status == :not_found && error.is_a?(Hash) && error[:campaign]
            render file: Rails.public_path.join("404.html"), status: :not_found, layout: false
          else
            redirect_to campaign_path(params[:id]), alert: "Đồng bộ lại thất bại: #{message}"
          end
        else
          render json: { error: message }, status: status
        end
      end

      def resync_check_resource_status_and_message(error)
        return [ :unauthorized, "Unauthorized" ] unless error.is_a?(Hash)

        if error[:campaign]
          [ :not_found, "Campaign not found" ]
        elsif error[:platform_campaigns]
          [ :not_found, "Platform campaign not found" ]
        else
          [ :unprocessable_content, extract_error_message(error) ]
        end
      end

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

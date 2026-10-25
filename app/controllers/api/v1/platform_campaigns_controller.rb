# frozen_string_literal: true

module Api
  module V1
    class PlatformCampaignsController < ApplicationController
      skip_before_action :verify_authenticity_token, raise: false
      skip_before_action :allow_browser, raise: false
      before_action :authenticate_user!

      rescue_from NameError, NotImplementedError, with: :handle_platform_error

      def publish
        PlatformCampaigns::PublishService.call(full_request_params) do |m|
          m.success do |result|
            render json: {
              success: true,
              data: {
                platform_campaigns: PlatformCampaignBlueprint.render_as_hash(result[:platform_campaigns]),
                message: "Campaign publish initiated successfully"
              },
              errors: nil
            }, status: :ok
          end

          m.failure(:validation) do |errors|
            render json: { success: false, data: nil, errors: errors }, status: :unprocessable_content
          end

          m.failure(:check_resource) do |error|
            render_publish_check_resource_failure(error)
          end

          m.failure do |error|
            render json: { success: false, data: nil, errors: extract_error_message(error) }, status: :unprocessable_content
          end
        end
      end

      def resync
        PlatformCampaigns::ResyncService.call(full_request_params) do |m|
          m.success do |result|
            render json: {
              success: true,
              data: {
                platform_campaigns: PlatformCampaignBlueprint.render_as_hash(result[:platform_campaigns]),
                message: "Campaign resync initiated successfully"
              },
              errors: nil
            }, status: :ok
          end

          m.failure(:validation) do |errors|
            render json: { success: false, data: nil, errors: errors }, status: :unprocessable_content
          end

          m.failure(:check_resource) do |error|
            render_resync_check_resource_failure(error)
          end

          m.failure(:detect_drift) do |error|
            render json: { success: false, data: nil, errors: extract_error_message(error) }, status: :unprocessable_content
          end

          m.failure do |error|
            render json: { success: false, data: nil, errors: extract_error_message(error) }, status: :unprocessable_content
          end
        end
      end

      private

      def handle_platform_error(exception)
        render json: {
          success: false,
          data: nil,
          errors: exception.message.presence || "Platform not supported"
        }, status: :not_found
      end

      def render_unauthorized(message = "Unauthorized")
        render json: { success: false, data: nil, errors: message }, status: :unauthorized
      end

      def render_publish_check_resource_failure(error)
        status, message = publish_check_resource_status_and_message(error)
        render json: { success: false, data: nil, errors: message }, status: status
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
        render json: { success: false, data: nil, errors: message }, status: status
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

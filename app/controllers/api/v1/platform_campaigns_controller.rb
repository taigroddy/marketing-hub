# frozen_string_literal: true

module Api
  module V1
    class PlatformCampaignsController < Api::BaseController
      before_action :authenticate_user!

      rescue_from NameError, NotImplementedError, with: :handle_platform_error

      def publish
        PlatformCampaigns::PublishService.call(full_request_params) do |m|
          m.success do |result|
            render json: {
              success: true,
              data: {
                platform_campaigns: PlatformCampaignBlueprint.render_as_hash(result[:platform_campaigns]),
                message: I18n.t("platform_campaigns.messages.publish_initiated")
              },
              errors: nil
            }, status: :ok
          end

          m.failure(:validation) do |errors|
            render json: { success: false, data: nil, errors: errors }, status: :unprocessable_content
          end

          m.failure(:check_resource) do |error|
            status, message = if !error.is_a?(Hash)
                                [ :unauthorized, I18n.t("errors.unauthorized", default: "Unauthorized") ]
            elsif error[:campaign] || error[:platform_accounts]
                                [ :not_found, I18n.t("errors.not_found", default: "Record not found") ]
            elsif error[:platform_account_ids]
                                [ :conflict, I18n.t("errors.conflict_published", default: "Already published for this campaign") ]
            elsif error[:error]
                                [ :unprocessable_content, error[:error] ]
            else
                                [ :unprocessable_content, extract_error_message(error) ]
            end
            render json: { success: false, data: nil, errors: message }, status: status
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
                message: I18n.t("platform_campaigns.messages.resync_initiated")
              },
              errors: nil
            }, status: :ok
          end

          m.failure(:validation) do |errors|
            render json: { success: false, data: nil, errors: errors }, status: :unprocessable_content
          end

          m.failure(:check_resource) do |error|
            status, message = if !error.is_a?(Hash)
                                [ :unauthorized, I18n.t("errors.unauthorized", default: "Unauthorized") ]
            elsif error[:campaign] || error[:platform_campaigns]
                                [ :not_found, I18n.t("errors.not_found", default: "Record not found") ]
            else
                                [ :unprocessable_content, extract_error_message(error) ]
            end
            render json: { success: false, data: nil, errors: message }, status: status
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
          errors: exception.message.presence || I18n.t("platform_accounts.messages.not_supported")
        }, status: :not_found
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

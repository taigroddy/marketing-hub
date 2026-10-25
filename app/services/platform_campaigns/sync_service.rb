# frozen_string_literal: true

module PlatformCampaigns
  class SyncService < ApplicationService
    include PlatformCampaigns::BroadcastSupport

    step :check_resource
    step :call_platform_api
    step :persist_result
    step :broadcast_realtime

    protected

    def check_resource(input)
      id = input[:platform_campaign_id] || input[:id]
      platform_campaign = PlatformCampaign.unscoped.find_by(id: id)
      return Failure(platform_campaign: [ I18n.t("errors.not_found") ]) unless platform_campaign

      Success(input.merge(
        platform_campaign: platform_campaign,
        campaign: Campaign.unscoped.find_by(id: platform_campaign.campaign_id),
        account: PlatformAccount.unscoped.find_by(id: platform_campaign.platform_account_id)
      ))
    end

    def call_platform_api(input)
      threshold = Rails.env.test? ? 1 : 0
      if ActiveRecord::Base.connection.open_transactions > threshold
        raise "Violation: 3rd party API called inside DB transaction"
      end

      platform_campaign = input[:platform_campaign]
      campaign = input[:campaign]
      account = input[:account]
      platform_name = account.platform_name.to_s.downcase

      client_class = "Clients::AdCampaign::#{platform_name.classify}Client".constantize
      client = client_class.new(
        access_token: account.access_token,
        account_id: account.account_id
      )

      api_result = if platform_campaign.external_campaign_id.present?
        client.update_campaign(
          campaign_id: platform_campaign.external_campaign_id,
          budget: campaign.budget,
          name: campaign.name
        )
      else
        client.create_campaign(
          name: campaign.name,
          objective: campaign.objective,
          budget: campaign.budget,
          account_id: account.account_id
        )
      end

      Success(input.merge(api_result: api_result))
    rescue NameError
      Success(input.merge(api_result: Failure(error: I18n.t("platform_accounts.messages.not_supported"))))
    rescue StandardError, ScriptError => e
      Success(input.merge(api_result: Failure(error: e.message)))
    end

    def persist_result(input)
      platform_campaign = input[:platform_campaign]
      result = input[:api_result]
      now = Time.current

      if result.success?
        data = result.value!
        external_id = data[:id] || platform_campaign.external_campaign_id
        PlatformCampaign.upsert(
          {
            id: platform_campaign.id,
            campaign_id: platform_campaign.campaign_id,
            platform_account_id: platform_campaign.platform_account_id,
            external_campaign_id: external_id,
            sync_status: "synced",
            synced_at: now,
            last_error_message: nil,
            updated_at: now
          },
          unique_by: :id
        )
        campaign = input[:campaign]
        campaign&.update_columns(status: "published", updated_at: now)
      else
        error_message = result.failure.is_a?(Hash) ? (result.failure[:error] || result.failure.values.flatten.join(", ")) : result.failure.to_s
        PlatformCampaign.upsert(
          {
            id: platform_campaign.id,
            campaign_id: platform_campaign.campaign_id,
            platform_account_id: platform_campaign.platform_account_id,
            external_campaign_id: platform_campaign.external_campaign_id,
            sync_status: "failed",
            last_error_message: error_message,
            updated_at: now
          },
          unique_by: :id
        )
      end

      Success(input)
    end

    def broadcast_realtime(input)
      campaign = input[:campaign]
      broadcast_campaign_updates(campaign)

      reloaded_platform_campaign = PlatformCampaign.unscoped.find(input[:platform_campaign].id)

      if input[:api_result].success?
        Success(
          platform_campaign: reloaded_platform_campaign,
          campaign: Campaign.unscoped.find(campaign.id),
          result: input[:api_result].value!
        )
      else
        Failure(input[:api_result].failure)
      end
    end
  end
end

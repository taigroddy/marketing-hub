# frozen_string_literal: true

module PlatformCampaigns
  class ResyncService < ApplicationService
    include PlatformCampaigns::BroadcastSupport

    step :validation
    step :check_resource
    step :detect_drift
    step :mark_sync_status_pending
    step :broadcast_pending
    step :enqueue_resync_worker

    protected

    def validation(input)
      result = PlatformCampaigns::ResyncContract.new.call(input)
      if result.success?
        Success(result.to_h)
      else
        Failure(result.errors.to_h)
      end
    end

    def check_resource(input)
      campaign = Campaign.find_by(id: input[:id])
      return Failure(campaign: [ I18n.t("errors.not_found") ]) if campaign.nil?

      account_class = "PlatformAccount::#{input[:platform].to_s.classify}".constantize
      client_class = "Clients::AdCampaign::#{input[:platform].to_s.classify}Client".constantize
      client_class.new

      records = campaign.platform_campaigns.joins(:platform_account)
                        .where(platform_accounts: { type: account_class.name })
                        .where(id: input[:platform_campaign_id])

      return Failure(platform_campaigns: [ I18n.t("errors.not_found") ]) if records.empty?

      Success(input.merge(campaign: campaign, records: records.to_a))
    end

    def detect_drift(input)
      drifted_records = input[:records].select(&:drifted?)

      if drifted_records.empty? && !input[:force]
        return Failure(error: I18n.t("platform_campaigns.messages.no_drift_detected"))
      end

      target_records = input[:force] ? input[:records] : drifted_records
      Success(input.merge(target_records: target_records))
    end

    def mark_sync_status_pending(input)
      now = Time.current

      updates = input[:target_records].map do |pc|
        {
          id: pc.id,
          campaign_id: pc.campaign_id,
          platform_account_id: pc.platform_account_id,
          external_campaign_id: pc.external_campaign_id,
          sync_status: "pending",
          last_error_message: nil,
          created_at: pc.created_at,
          updated_at: now
        }
      end

      PlatformCampaign.upsert_all(updates, unique_by: :id)

      Success(input)
    end

    def broadcast_pending(input)
      broadcast_campaign_updates(input[:campaign])
      Success(input)
    end

    def enqueue_resync_worker(input)
      input[:target_records].each do |pc|
        SyncCampaignJob.perform_later(pc.id)
      end

      reloaded_records = PlatformCampaign.where(id: input[:target_records].map(&:id))
      Success(campaign: input[:campaign], platform_campaigns: reloaded_records)
    end
  end
end

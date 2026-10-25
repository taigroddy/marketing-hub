# frozen_string_literal: true

module PlatformCampaigns
  class ResyncService < ApplicationService
    step :validation
    step :check_resource
    step :detect_drift
    step :mark_sync_status_pending
    step :enqueue_resync_worker

    protected

    def validation(input)
      normalized = input.dup.deep_symbolize_keys

      campaign_id = normalized[:campaign_id] || normalized[:id]
      platform = normalized[:platform].to_s.downcase

      errors = {}
      errors[:campaign_id] = [ "must be filled" ] if campaign_id.blank?

      if errors.any?
        Failure(errors)
      else
        Success(normalized.merge(
          campaign_id: campaign_id.to_i,
          platform: platform
        ))
      end
    end

    def check_resource(input)
      user = input[:user] || Current.user
      return Failure(:unauthorized) if user.nil?

      campaign = user.campaigns.find_by(id: input[:campaign_id])
      return Failure(campaign: [ "not found" ]) if campaign.nil?

      records = campaign.platform_campaigns.joins(:platform_account)
                        .where(platform_accounts: { type: "PlatformAccount::#{input[:platform].camelize}" })

      if input[:platform_campaign_id].present?
        records = records.where(id: input[:platform_campaign_id])
      end

      return Failure(platform_campaigns: [ "not found" ]) if records.empty?

      Success(input.merge(user: user, campaign: campaign, records: records.to_a))
    end

    def detect_drift(input)
      drifted_records = input[:records].select(&:drifted?)

      if drifted_records.empty? && !input[:force]
        return Failure(error: "No drift detected between campaign and platform")
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

    def enqueue_resync_worker(input)
      input[:target_records].each do |pc|
        if input[:async] == false
          SyncCampaignJob.perform_now(pc.id)
        else
          SyncCampaignJob.perform_later(pc.id)
        end
      end

      reloaded_records = PlatformCampaign.where(id: input[:target_records].map(&:id))
      Success(campaign: input[:campaign], platform_campaigns: reloaded_records)
    end
  end
end

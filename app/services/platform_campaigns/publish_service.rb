# frozen_string_literal: true

module PlatformCampaigns
  class PublishService < ApplicationService
    include PlatformCampaigns::BroadcastSupport

    step :validation
    step :check_resource
    step :persist_platform_campaigns
    step :broadcast_pending
    step :enqueue_sync_workers

    protected

    def validation(input)
      result = PlatformCampaigns::PublishContract.new.call(input)
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

      accounts = account_class.where(id: input[:platform_account_ids]).to_a
      if accounts.size != input[:platform_account_ids].size
        return Failure(platform_accounts: [ I18n.t("errors.not_found") ])
      end

      already_published = PlatformCampaign.where(
        campaign_id: campaign.id,
        platform_account_id: accounts.map(&:id)
      ).exists?

      if already_published
        return Failure(platform_account_ids: [ I18n.t("errors.conflict_published") ])
      end

      Success(input.merge(campaign: campaign, accounts: accounts))
    end

    def persist_platform_campaigns(input)
      campaign = input[:campaign]
      accounts = input[:accounts]
      now = Time.current

      records_data = accounts.map do |account|
        {
          campaign_id: campaign.id,
          platform_account_id: account.id,
          sync_status: "pending",
          created_at: now,
          updated_at: now
        }
      end

      platform_campaigns = nil
      ActiveRecord::Base.transaction do
        platform_campaigns = PlatformCampaign.upsert_all(records_data, unique_by: [ :campaign_id, :platform_account_id ], returning: [ :id ])
        campaign.update!(status: "published")
      end

      Success(input.merge(platform_campaigns: platform_campaigns))
    end

    def broadcast_pending(input)
      broadcast_campaign_updates(input[:campaign])
      Success(input)
    end

    def enqueue_sync_workers(input)
      platform_campaigns = input[:platform_campaigns]
      ids = platform_campaigns.map { |pc| pc.is_a?(Hash) ? (pc["id"] || pc[:id]) : pc.id }

      ids.each do |id|
        SyncCampaignJob.perform_later(id)
      end

      final_records = PlatformCampaign.where(id: ids)
      Success(campaign: input[:campaign], platform_campaigns: final_records)
    end
  end
end

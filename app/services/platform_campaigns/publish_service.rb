# frozen_string_literal: true

module PlatformCampaigns
  class PublishService < ApplicationService
    step :validation
    step :check_resource
    step :persist_platform_campaigns
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
      return Failure(campaign: [ "not found" ]) if campaign.nil?

      account_class = "PlatformAccount::#{input[:platform].to_s.classify}".constantize
      client_class = "Clients::AdCampaign::#{input[:platform].to_s.classify}Client".constantize
      client_class.new

      accounts = account_class.where(id: input[:platform_account_ids]).to_a
      if accounts.size != input[:platform_account_ids].size
        return Failure(platform_accounts: [ "invalid or not found" ])
      end

      already_published = PlatformCampaign.where(
        campaign_id: campaign.id,
        platform_account_id: accounts.map(&:id)
      ).exists?

      if already_published
        return Failure(platform_account_ids: [ "already published for this campaign" ])
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

      PlatformCampaign.upsert_all(records_data, unique_by: [ :campaign_id, :platform_account_id ])

      platform_campaigns = PlatformCampaign.where(
        campaign_id: campaign.id,
        platform_account_id: accounts.map(&:id)
      ).to_a

      Success(input.merge(platform_campaigns: platform_campaigns))
    end

    def enqueue_sync_workers(input)
      platform_campaigns = input[:platform_campaigns]

      platform_campaigns.each do |pc|
        if input[:async] == false
          SyncCampaignJob.perform_now(pc.id)
        else
          SyncCampaignJob.perform_later(pc.id)
        end
      end

      final_records = PlatformCampaign.where(id: platform_campaigns.map(&:id))
      Success(campaign: input[:campaign], platform_campaigns: final_records)
    end
  end
end

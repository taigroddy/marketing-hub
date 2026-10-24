# frozen_string_literal: true

module PlatformCampaigns
  class PublishService < ApplicationService
    step :validation
    step :check_resource
    step :process

    protected

    def validation(input)
      normalized = input.dup.deep_symbolize_keys

      campaign_id = normalized[:campaign_id] || normalized[:id]
      platform = normalized[:platform].to_s.downcase

      account_ids = normalized[:platform_account_ids] || normalized[:platform_account_id]
      if account_ids.nil? && normalized[:platform_campaign].is_a?(Hash)
        account_ids = normalized[:platform_campaign][:platform_account_ids]
      end
      account_ids = Array(account_ids).flatten.map(&:to_s).reject(&:blank?)

      errors = {}
      errors[:campaign_id] = [ "must be filled" ] if campaign_id.blank?
      errors[:platform_account_ids] = [ "must be filled" ] if account_ids.empty?

      if errors.any?
        Failure(errors)
      else
        Success(normalized.merge(
          campaign_id: campaign_id.to_i,
          platform: platform,
          platform_account_ids: account_ids.map(&:to_i)
        ))
      end
    end

    def check_resource(input)
      user = input[:user] || Current.user
      return Failure(:unauthorized) if user.nil?

      campaign = user.campaigns.find_by(id: input[:campaign_id])
      return Failure(campaign: [ "not found" ]) if campaign.nil?

      return Failure(error: "Google platform integration coming soon") if input[:platform] == "google"

      accounts = user.platform_accounts.where(id: input[:platform_account_ids]).to_a
      if accounts.size != input[:platform_account_ids].size || accounts.any? { |a| a.platform_name.downcase != input[:platform] }
        return Failure(platform_accounts: [ "invalid or not found" ])
      end

      already_published = PlatformCampaign.where(
        campaign_id: campaign.id,
        platform_account_id: accounts.map(&:id)
      ).exists?

      if already_published
        return Failure(platform_account_ids: [ "already published for this campaign" ])
      end

      Success(input.merge(user: user, campaign: campaign, accounts: accounts))
    end

    def process(input)
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
      )

      platform_campaigns.each do |pc|
        if input[:async] == false
          SyncCampaignJob.perform_now(pc.id)
        else
          SyncCampaignJob.perform_later(pc.id)
        end
      end

      final_records = PlatformCampaign.where(id: platform_campaigns.map(&:id))
      Success(campaign: campaign, platform_campaigns: final_records)
    end
  end
end

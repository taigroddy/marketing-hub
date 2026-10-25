# frozen_string_literal: true

module PlatformCampaigns
  module BroadcastSupport
    def broadcast_campaign_updates(campaign)
      reloaded_campaign = Campaign.unscoped.find(campaign.id)
      connected_accounts = PlatformAccount.unscoped.where(user_id: reloaded_campaign.user_id).connected
      ordered_platform_campaigns = PlatformCampaign.unscoped.where(campaign_id: reloaded_campaign.id).includes(:platform_account).order(created_at: :desc)

      Turbo::StreamsChannel.broadcast_replace_to(
        "campaign_#{reloaded_campaign.id}",
        target: "campaign_header_section",
        attributes: { method: :morph },
        partial: "campaigns/campaign_header_section",
        locals: {
          campaign: reloaded_campaign,
          platform_campaigns: ordered_platform_campaigns
        }
      )

      Turbo::StreamsChannel.broadcast_replace_to(
        "campaign_#{reloaded_campaign.id}",
        target: "platform_accounts_section",
        attributes: { method: :morph },
        partial: "campaigns/platform_accounts_section",
        locals: {
          campaign: reloaded_campaign,
          platform_accounts: connected_accounts,
          platform_campaigns: ordered_platform_campaigns
        }
      )

      Turbo::StreamsChannel.broadcast_replace_to(
        "campaign_#{reloaded_campaign.id}",
        target: "platform_campaigns_section",
        attributes: { method: :morph },
        partial: "campaigns/platform_campaigns_section",
        locals: {
          campaign: reloaded_campaign,
          platform_campaigns: ordered_platform_campaigns
        }
      )
    end
  end
end

# frozen_string_literal: true

class SyncCampaignJob < ApplicationJob
  queue_as :default

  def perform(platform_campaign_id)
    platform_campaign = PlatformCampaign.unscoped.find_by(id: platform_campaign_id)
    return unless platform_campaign

    PlatformCampaigns::SyncService.call(platform_campaign_id: platform_campaign.id)
  end
end

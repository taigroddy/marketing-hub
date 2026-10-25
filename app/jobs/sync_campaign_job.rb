# frozen_string_literal: true

class SyncCampaignJob < ApplicationJob
  queue_as :default

  def perform(platform_campaign_id)
    PlatformCampaigns::SyncService.call(platform_campaign_id: platform_campaign_id)
  end
end

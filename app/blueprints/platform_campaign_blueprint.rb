# frozen_string_literal: true

class PlatformCampaignBlueprint < ApplicationBlueprint
  identifier :id

  fields :campaign_id, :platform_account_id, :external_campaign_id, :synced_at, :sync_status, :last_error_message, :created_at, :updated_at

  field :out_of_sync do |record|
    record.out_of_sync?
  end
end

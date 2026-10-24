# frozen_string_literal: true

class PlatformCampaign < ApplicationRecord
  belongs_to :campaign
  belongs_to :platform_account

  def out_of_sync?
    synced_at.present? && campaign.present? && campaign.updated_at > synced_at
  end
  alias drifted? out_of_sync?
end

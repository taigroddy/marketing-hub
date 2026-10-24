# frozen_string_literal: true

class PlatformCampaign < ApplicationRecord
  belongs_to :campaign
  belongs_to :platform_account

  validates :campaign_id, presence: true
  validates :platform_account_id, presence: true, uniqueness: { scope: :campaign_id }
  validates :sync_status, presence: true, inclusion: { in: %w[pending synced failed] }

  def out_of_sync?
    synced_at.present? && campaign.present? && campaign.updated_at > synced_at
  end
  alias drifted? out_of_sync?
end

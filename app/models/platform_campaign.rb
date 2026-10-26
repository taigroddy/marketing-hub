# frozen_string_literal: true

# == Schema Information
#
# Table name: platform_campaigns
#
#  id                   :bigint           not null, primary key
#  last_error_message   :text
#  sync_status          :string           default("pending"), not null
#  synced_at            :datetime
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  campaign_id          :bigint           not null
#  external_campaign_id :string
#  platform_account_id  :bigint           not null
#
# Indexes
#
#  idx_on_campaign_id_platform_account_id_878baa76ee  (campaign_id,platform_account_id) UNIQUE
#  index_platform_campaigns_on_campaign_id            (campaign_id)
#  index_platform_campaigns_on_external_campaign_id   (external_campaign_id)
#  index_platform_campaigns_on_platform_account_id    (platform_account_id)
#
# Foreign Keys
#
#  fk_rails_...  (campaign_id => campaigns.id)
#  fk_rails_...  (platform_account_id => platform_accounts.id)
#
class PlatformCampaign < ApplicationRecord
  belongs_to :campaign, -> { unscope(where: :user_id) }
  belongs_to :platform_account, -> { unscope(where: :user_id) }

  def out_of_sync?
    synced_at.present? && campaign.present? && campaign.updated_at > synced_at
  end
  alias drifted? out_of_sync?
end

# frozen_string_literal: true

module PlatformCampaigns
  class PublishContract < ApplicationContract
    params do
      optional(:id).filled(:integer)
      optional(:campaign_id).filled(:integer)
      required(:platform).filled(:string, included_in?: %w[facebook google])
      required(:platform_account_ids).filled(:array, min_size?: 1).each(:integer)
      optional(:async).maybe(:bool)
    end

    rule(:id, :campaign_id) do
      if values[:id].blank? && values[:campaign_id].blank?
        key(:campaign_id).failure("must be filled")
      end
    end
  end
end

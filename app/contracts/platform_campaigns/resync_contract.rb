# frozen_string_literal: true

module PlatformCampaigns
  class ResyncContract < ApplicationContract
    params do
      optional(:id).filled(:integer)
      optional(:campaign_id).filled(:integer)
      required(:platform).filled(:string, included_in?: %w[facebook google])
      optional(:platform_campaign_id).maybe(:integer)
      optional(:force).maybe(:bool)
      optional(:async).maybe(:bool)
    end

    rule(:id, :campaign_id) do
      if values[:id].blank? && values[:campaign_id].blank?
        key(:campaign_id).failure("must be filled")
      end
    end
  end
end

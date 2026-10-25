# frozen_string_literal: true

module PlatformCampaigns
  class ResyncContract < ApplicationContract
    params do
      required(:id).filled(:integer)
      required(:platform).filled(:string, included_in?: %w[facebook google])
      required(:platform_campaign_id).filled(:integer)
      optional(:force).maybe(:bool)
    end
  end
end

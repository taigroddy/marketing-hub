# frozen_string_literal: true

module PlatformCampaigns
  class PublishContract < ApplicationContract
    params do
      required(:id).filled(:integer)
      required(:platform).filled(:string, included_in?: %w[facebook google])
      required(:platform_account_ids).filled(:array, min_size?: 1).each(:integer)
      optional(:async).maybe(:bool)
    end
  end
end

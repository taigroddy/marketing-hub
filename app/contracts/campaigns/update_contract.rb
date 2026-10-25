# frozen_string_literal: true

module Campaigns
  class UpdateContract < ApplicationContract
    params do
      optional(:id).filled
      required(:budget).filled(:decimal, gt?: 0)
    end
  end
end

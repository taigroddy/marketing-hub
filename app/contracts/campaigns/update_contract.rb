# frozen_string_literal: true

module Campaigns
  class UpdateContract < ApplicationContract
    params do
      required(:id).filled(:integer)
      required(:budget).filled(:decimal, gt?: 0)
    end
  end
end

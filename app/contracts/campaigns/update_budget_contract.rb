# frozen_string_literal: true

module Campaigns
  class UpdateBudgetContract < ApplicationContract
    params do
      optional(:id).filled
      required(:budget).filled(:decimal, gt?: 0)
    end
  end
end

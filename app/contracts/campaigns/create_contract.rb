# frozen_string_literal: true

module Campaigns
  class CreateContract < ApplicationContract
    params do
      required(:name).filled(:string)
      required(:objective).filled(:string)
      required(:budget).filled(:decimal, gt?: 0)
      optional(:status).maybe(:string)
    end

    rule(:status) do
      if value.present? && !%w[draft active paused completed].include?(value)
        key.failure("is not included in the list")
      end
    end
  end
end

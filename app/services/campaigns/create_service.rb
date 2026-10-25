# frozen_string_literal: true

module Campaigns
  class CreateService < ApplicationService
    step :validation
    step :create_campaign_record

    protected

    def validation(input)
      result = Campaigns::CreateContract.new.call(input)
      if result.success?
        Success(result.to_h)
      else
        Failure(result.errors.to_h)
      end
    end

    def create_campaign_record(input)
      campaign = Campaign.new(
        name: input[:name],
        objective: input[:objective],
        budget: input[:budget],
        status: input[:status].presence || "draft"
      )

      if campaign.save
        Success(campaign: campaign)
      else
        Failure(campaign.errors.to_hash)
      end
    end
  end
end

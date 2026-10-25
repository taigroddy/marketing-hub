# frozen_string_literal: true

module Campaigns
  class UpdateService < ApplicationService
    step :validation
    step :check_resource
    step :update_campaign_budget

    protected

    def validation(input)
      result = Campaigns::UpdateContract.new.call(input)
      if result.success?
        Success(result.to_h)
      else
        Failure(result.errors.to_h)
      end
    end

    def check_resource(input)
      campaign = Campaign.find_by(id: input[:id])
      return Failure(:not_found) if campaign.nil?

      Success(input.merge(campaign: campaign))
    end

    def update_campaign_budget(input)
      campaign = input[:campaign]
      if campaign.update(budget: input[:budget])
        Success(campaign: campaign)
      else
        Failure(campaign.errors.to_hash)
      end
    end
  end
end

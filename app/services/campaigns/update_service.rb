# frozen_string_literal: true

module Campaigns
  class UpdateService < ApplicationService
    step :validation
    step :check_resource
    step :process

    protected

    def validation(input)
      normalized = input.dup.deep_symbolize_keys

      provided_user = normalized[:user] if normalized[:user].is_a?(User)
      provided_campaign = normalized[:campaign] if normalized[:campaign].is_a?(Campaign)

      if normalized[:campaign].is_a?(Hash)
        nested = normalized.delete(:campaign)
        normalized = nested.merge(normalized)
      end

      normalized[:id] ||= provided_campaign.id if provided_campaign

      result = Campaigns::UpdateContract.new.call(normalized)
      if result.success?
        data = result.to_h
        data[:user] = provided_user if provided_user
        data[:campaign] = provided_campaign if provided_campaign
        Success(data)
      else
        Failure(result.errors.to_h)
      end
    end

    def check_resource(input)
      user = input[:user] || Current.user
      return Failure(:unauthorized) if user.nil?

      campaign = input[:campaign] || user.campaigns.find_by(id: input[:id])
      return Failure(:not_found) if campaign.nil? || campaign.user_id != user.id

      Success(input.merge(campaign: campaign, user: user))
    end

    def process(input)
      campaign = input[:campaign]
      if campaign.update(budget: input[:budget])
        Success(campaign: campaign)
      else
        Failure(campaign.errors.to_hash)
      end
    end
  end
end

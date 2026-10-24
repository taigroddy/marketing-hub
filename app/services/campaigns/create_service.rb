# frozen_string_literal: true

module Campaigns
  class CreateService < ApplicationService
    step :validation
    step :check_resource
    step :process

    protected

    def validation(input)
      normalized = input.dup.deep_symbolize_keys
      provided_user = normalized[:user] if normalized[:user].is_a?(User)

      if normalized[:campaign].is_a?(Hash)
        nested = normalized.delete(:campaign)
        normalized = nested.merge(normalized)
      end

      result = Campaigns::CreateContract.new.call(normalized)
      if result.success?
        data = result.to_h
        data[:user] = provided_user if provided_user
        Success(data)
      else
        Failure(result.errors.to_h)
      end
    end

    def check_resource(input)
      user = input[:user] || Current.user
      return Failure(:unauthorized) if user.nil?

      Success(input.merge(user: user))
    end

    def process(input)
      campaign = input[:user].campaigns.build(
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

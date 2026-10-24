# frozen_string_literal: true

module AdCampaign
  class BaseClient
    def create_campaign(**_kwargs)
      raise NotImplementedError, "#{self.class.name} must implement #create_campaign"
    end

    def update_campaign(**_kwargs)
      raise NotImplementedError, "#{self.class.name} must implement #update_campaign"
    end

    def fetch_campaign(**_kwargs)
      raise NotImplementedError, "#{self.class.name} must implement #fetch_campaign"
    end
  end
end

module Clients
  module AdCampaign
    BaseClient = ::AdCampaign::BaseClient
  end
end

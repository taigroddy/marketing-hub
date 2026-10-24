# frozen_string_literal: true

module AdCampaign
  class GoogleClient < BaseClient
    def initialize(*_args, **_kwargs)
      super()
      raise NotImplementedError, "Google platform integration coming soon"
    end

    def create_campaign(**_kwargs)
      raise NotImplementedError, "Google platform integration coming soon"
    end

    def update_campaign(**_kwargs)
      raise NotImplementedError, "Google platform integration coming soon"
    end

    def fetch_campaign(**_kwargs)
      raise NotImplementedError, "Google platform integration coming soon"
    end
  end
end

module Clients
  module AdCampaign
    GoogleClient = ::AdCampaign::GoogleClient
  end
end

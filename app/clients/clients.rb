# frozen_string_literal: true

module Clients
  module OAuth
    def self.const_missing(name)
      ::OAuth.const_get(name)
    end
  end

  module AdCampaign
    def self.const_missing(name)
      ::AdCampaign.const_get(name)
    end
  end
end

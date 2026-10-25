# frozen_string_literal: true

module OAuth
  class GoogleClient < BaseClient
    def initialize(*_args, **_kwargs)
      super()
      raise NotImplementedError, "Google platform integration coming soon"
    end

    def authorize_url(**_kwargs)
      raise NotImplementedError, "Google platform integration coming soon"
    end

    def exchange_code(*_args, **_kwargs)
      raise NotImplementedError, "Google platform integration coming soon"
    end

    def refresh_token(*_args, **_kwargs)
      raise NotImplementedError, "Google platform integration coming soon"
    end

    def revoke_token(*_args, **_kwargs)
      raise NotImplementedError, "Google platform integration coming soon"
    end
  end
end

module Clients
  module OAuth
    GoogleClient = ::OAuth::GoogleClient
  end
end

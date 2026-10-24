# frozen_string_literal: true

module OAuth
  class BaseClient
    def authorize_url(**_kwargs)
      raise NotImplementedError, "#{self.class.name} must implement #authorize_url"
    end

    def exchange_code(*_args, **_kwargs)
      raise NotImplementedError, "#{self.class.name} must implement #exchange_code"
    end

    def refresh_token(*_args, **_kwargs)
      raise NotImplementedError, "#{self.class.name} must implement #refresh_token"
    end
  end
end

module Clients
  module OAuth
    BaseClient = ::OAuth::BaseClient
  end
end

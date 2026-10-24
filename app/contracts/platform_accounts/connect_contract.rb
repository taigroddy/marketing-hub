# frozen_string_literal: true

module PlatformAccounts
  class ConnectContract < ApplicationContract
    params do
      required(:platform).filled(:string)
      required(:code).filled(:string)
      optional(:state).maybe(:string)
      optional(:redirect_uri).maybe(:string)
      optional(:account_id).maybe(:string)
      optional(:name).maybe(:string)
    end

    rule(:platform) do
      key.failure("must be facebook or google") unless %w[facebook google].include?(value)
    end
  end
end

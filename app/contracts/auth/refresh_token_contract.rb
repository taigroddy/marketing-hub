# frozen_string_literal: true

module Auth
  class RefreshTokenContract < ApplicationContract
    params do
      required(:refresh_token).filled(:string)
      optional(:device_info).maybe(:string)
    end
  end
end

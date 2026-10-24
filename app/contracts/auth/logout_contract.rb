# frozen_string_literal: true

module Auth
  class LogoutContract < ApplicationContract
    params do
      required(:refresh_token).filled(:string)
    end
  end
end

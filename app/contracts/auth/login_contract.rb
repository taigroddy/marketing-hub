# frozen_string_literal: true

module Auth
  class LoginContract < ApplicationContract
    params do
      required(:email).filled(:string)
      required(:password).filled(:string)
    end

    rule(:email) do
      key.failure("is invalid") unless URI::MailTo::EMAIL_REGEXP.match?(value)
    end
  end
end

# frozen_string_literal: true

module Auth
  class RegisterContract < ApplicationContract
    params do
      required(:email).filled(:string)
      required(:password).filled(:string, min_size?: 6)
      optional(:password_confirmation).maybe(:string)
    end

    rule(:email) do
      key.failure("is invalid") unless URI::MailTo::EMAIL_REGEXP.match?(value)
    end

    rule(:password_confirmation, :password) do
      if values[:password_confirmation].present? && values[:password] != values[:password_confirmation]
        key(:password_confirmation).failure("must match password")
      end
    end
  end
end

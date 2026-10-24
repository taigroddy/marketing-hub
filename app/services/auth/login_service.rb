# frozen_string_literal: true

module Auth
  class LoginService < ApplicationService
    contract Auth::LoginContract

    step :validation
    step :check_resource
    step :process

    protected

    def validation(input)
      normalized = input.respond_to?(:to_unsafe_h) ? input.to_unsafe_h : input.dup
      normalized = normalized.symbolize_keys if normalized.respond_to?(:symbolize_keys)
      normalized[:email] = normalized[:email].to_s.strip if normalized[:email].is_a?(String)
      super(normalized)
    end

    def check_resource(input)
      normalized_email = input[:email].to_s.strip.downcase
      user = User.find_by("lower(email) = ?", normalized_email)

      if user.nil? || !user.authenticate(input[:password])
        Failure(:invalid_credentials)
      elsif !user.confirmed?
        Failure(:unconfirmed_email)
      else
        Success(user: user)
      end
    end

    def process(input)
      user = input[:user]
      token = Authenticable.encode_jwt({ user_id: user.id })
      Success(user: user, token: token)
    end
  end
end

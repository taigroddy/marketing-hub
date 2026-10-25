# frozen_string_literal: true

module Auth
  class LogoutService < ApplicationService
    step :validation
    step :find_and_verify_token
    step :revoke_user_token

    private

    def validation(input)
      result = Auth::LogoutContract.new.call(input)
      if result.success?
        Success(result.to_h)
      else
        Failure(result.errors.to_h)
      end
    end

    def find_and_verify_token(input)
      raw_token = input[:refresh_token]
      digest = UserToken.digest(raw_token)
      user_token = UserToken.find_by(token_digest: digest)

      return Failure(:token_not_found) if user_token.nil?
      return Failure(:token_revoked) if user_token.revoked?
      return Failure(:token_expired) if user_token.expired?

      Success(input.merge(user_token: user_token))
    end

    def revoke_user_token(input)
      user_token = input[:user_token]
      user_token.revoke!

      Success(user_token: user_token)
    end
  end
end

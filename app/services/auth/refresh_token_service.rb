# frozen_string_literal: true

module Auth
  class RefreshTokenService < ApplicationService
    step :validation
    step :find_and_verify_token
    step :issue_new_tokens

    private

    def validation(input)
      result = Auth::RefreshTokenContract.new.call(input)
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

      Success(input.merge(user_token: user_token, user: user_token.user))
    end

    def issue_new_tokens(input)
      user_token = input[:user_token]
      user = input[:user]

      new_refresh_token = user_token.rotate!(new_device_info: input[:device_info])
      access_token = Authenticable.encode_jwt({ user_id: user.id, user_token_id: user_token.id }, 1.hour.from_now)

      Success(
        user: user,
        user_token: user_token,
        token: access_token,
        refresh_token: new_refresh_token
      )
    end
  end
end

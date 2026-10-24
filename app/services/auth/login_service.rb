# frozen_string_literal: true

module Auth
  class LoginService < ApplicationService
    step :validation
    step :check_resource
    step :process

    private

    def validation(input)
      email = input[:email] || input["email"]
      cleaned = input.is_a?(Hash) ? input.symbolize_keys : {}
      cleaned[:email] = email.to_s.strip if email.is_a?(String)

      result = Auth::LoginContract.new.call(cleaned)
      if result.success?
        Success(result.to_h.merge(device_info: cleaned[:device_info]))
      else
        Failure(result.errors.to_h)
      end
    end

    def check_resource(input)
      normalized_email = input[:email].to_s.strip.downcase
      user = User.find_by("lower(email) = ?", normalized_email)

      if user.nil? || !user.authenticate(input[:password])
        Failure(:invalid_credentials)
      elsif !user.confirmed?
        Failure(:unconfirmed_email)
      else
        Success(input.merge(user: user))
      end
    end

    def process(input)
      user = input[:user]
      user_token, refresh_token = UserToken.create_for_user!(user, device_info: input[:device_info])
      token = Authenticable.encode_jwt({ user_id: user.id, user_token_id: user_token.id }, 1.hour.from_now)

      Success(
        user: user,
        user_token: user_token,
        token: token,
        refresh_token: refresh_token
      )
    end
  end
end

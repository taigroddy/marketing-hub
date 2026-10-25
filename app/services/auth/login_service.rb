# frozen_string_literal: true

module Auth
  class LoginService < ApplicationService
    step :validation
    step :check_resource
    step :generate_session_tokens

    private

    def validation(input)
      result = Auth::LoginContract.new.call(input)
      if result.success?
        Success(result.to_h)
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

    def generate_session_tokens(input)
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

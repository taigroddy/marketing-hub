# frozen_string_literal: true

module Auth
  class RegisterService < ApplicationService
    step :validation
    step :check_resource
    step :process

    protected

    def validation(input)
      normalized = input.dup.symbolize_keys
      normalized[:email] = normalized[:email].to_s.strip if normalized[:email].is_a?(String)

      result = Auth::RegisterContract.new.call(normalized)
      if result.success?
        Success(result.to_h)
      else
        Failure(result.errors.to_h)
      end
    end

    def check_resource(input)
      normalized_email = input[:email].to_s.strip.downcase
      if User.where("lower(email) = ?", normalized_email).exists?
        Failure(email: [ "has already been taken" ])
      else
        Success(input.merge(email: normalized_email))
      end
    end

    def process(input)
      token = SecureRandom.hex(32)
      user = User.new(
        email: input[:email],
        password: input[:password],
        password_confirmation: input[:password_confirmation],
        confirmation_token: token,
        confirmation_sent_at: Time.current
      )

      if user.save
        UserMailer.confirmation_email(user).deliver_later
        Success(user: user)
      else
        Failure(user.errors.to_h)
      end
    end
  end
end

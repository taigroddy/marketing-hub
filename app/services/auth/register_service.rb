# frozen_string_literal: true

module Auth
  class RegisterService < ApplicationService
    step :validation
    step :check_resource
    step :create_user
    step :send_confirmation_email

    protected

    def validation(input)
      result = Auth::RegisterContract.new.call(input)
      if result.success?
        Success(result.to_h)
      else
        Failure(result.errors.to_h)
      end
    end

    def check_resource(input)
      normalized_email = input[:email].to_s.strip.downcase
      if User.where("lower(email) = ?", normalized_email).exists?
        Failure(email: [ I18n.t("services.auth.email_taken") ])
      else
        Success(input.merge(email: normalized_email))
      end
    end

    def create_user(input)
      token = SecureRandom.hex(32)
      user = User.new(
        email: input[:email],
        password: input[:password],
        password_confirmation: input[:password_confirmation],
        confirmation_token: token,
        confirmation_sent_at: Time.current
      )

      if user.save
        Success(input.merge(user: user))
      else
        Failure(user.errors.to_h)
      end
    end

    def send_confirmation_email(input)
      UserMailer.confirmation_email(input[:user]).deliver_later
      Success(user: input[:user])
    end
  end
end

# frozen_string_literal: true

module Auth
  class ConfirmEmailService < ApplicationService
    step :validation
    step :check_resource
    step :process

    protected

    def validation(input)
      token = input[:token].to_s.strip
      if token.blank?
        Failure(:invalid_token)
      else
        Success(token: token)
      end
    end

    def check_resource(input)
      user = User.find_by(confirmation_token: input[:token])
      if user.nil?
        Failure(:invalid_token)
      elsif user.confirmed?
        Failure(:already_confirmed)
      elsif token_expired?(user)
        Failure([ :resource_not_found, "Invalid or expired confirmation token" ])
      else
        Success(user: user)
      end
    end

    def process(input)
      user = input[:user]
      user.confirm!
      token = Authenticable.encode_jwt({ user_id: user.id })
      Success(user: user, token: token)
    end

    private

    def token_expired?(user)
      user.confirmation_sent_at.blank? || user.confirmation_sent_at <= 24.hours.ago
    end
  end
end

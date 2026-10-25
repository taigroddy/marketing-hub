# frozen_string_literal: true

module Auth
  class ConfirmEmailService < ApplicationService
    step :check_resource
    step :confirm_user_account

    protected

    def check_resource(input)
      token = (input[:token] || input["token"]).to_s.strip
      return Failure(:invalid_token) if token.blank?

      user = User.find_by(confirmation_token: token)
      if user.nil?
        Failure(:invalid_token)
      elsif user.confirmed?
        Failure(:already_confirmed)
      elsif user.confirmation_sent_at.blank? || user.confirmation_sent_at <= 24.hours.ago
        Failure([ :resource_not_found, "Invalid or expired confirmation token" ])
      else
        Success(user: user)
      end
    end

    def confirm_user_account(input)
      user = input[:user]
      user.confirm!
      token = Authenticable.encode_jwt({ user_id: user.id })
      Success(user: user, token: token)
    end
  end
end

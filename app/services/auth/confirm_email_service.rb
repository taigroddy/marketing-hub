# frozen_string_literal: true

module Auth
  class ConfirmEmailService < ApplicationService
    step :validation
    step :check_resource
    step :confirm_user_account

    private

    def validation(input)
      result = Auth::ConfirmEmailContract.new.call(input)
      if result.success?
        Success(result.to_h)
      else
        Failure(result.errors.to_h)
      end
    end

    def check_resource(input)
      user = User.find_by(confirmation_token: input[:token])
      if user.nil?
        Failure(:invalid_token)
      elsif user.confirmed?
        Failure(:already_confirmed)
      elsif user.confirmation_sent_at.blank? || user.confirmation_sent_at <= 24.hours.ago
        Failure([ :resource_not_found, I18n.t("auth.invalid_confirmation_token") ])
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

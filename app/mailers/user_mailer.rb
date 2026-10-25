# frozen_string_literal: true

class UserMailer < ApplicationMailer
  def confirmation_email(user)
    @user = user
    @token = user.confirmation_token
    @confirmation_url = confirm_email_url(token: @token)

    mail(to: @user.email, subject: I18n.t("mailers.user_mailer.confirmation_subject"))
  end
end

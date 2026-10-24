# frozen_string_literal: true

class UserMailer < ApplicationMailer
  def confirmation_email(user)
    @user = user
    @token = user.confirmation_token
    @confirmation_url = "http://marketing.localhost/confirm_email/#{@token}"

    mail(to: @user.email, subject: "Confirm your email address")
  end
end

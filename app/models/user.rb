# frozen_string_literal: true

class User < ApplicationRecord
  has_secure_password

  before_validation :normalize_email

  validates :email, presence: true,
                    uniqueness: { case_sensitive: false },
                    format: { with: URI::MailTo::EMAIL_REGEXP }

  def confirmed?
    confirmed_at.present?
  end

  def confirm!
    update(confirmed_at: Time.current, confirmation_token: nil)
  end

  private

  def normalize_email
    self.email = email.to_s.strip.downcase if email.present?
  end
end

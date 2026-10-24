# frozen_string_literal: true

class User < ApplicationRecord
  has_secure_password validations: false

  has_many :campaigns, dependent: :destroy
  has_many :platform_accounts, dependent: :destroy
  has_many :user_tokens, dependent: :destroy

  before_validation :normalize_email

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

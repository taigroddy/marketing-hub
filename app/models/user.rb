# frozen_string_literal: true

# == Schema Information
#
# Table name: users
#
#  id                   :bigint           not null, primary key
#  confirmation_sent_at :datetime
#  confirmation_token   :string
#  confirmed_at         :datetime
#  email                :string           not null
#  password_digest      :string           not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#
# Indexes
#
#  index_users_on_confirmation_token  (confirmation_token) UNIQUE
#  index_users_on_email               (email) UNIQUE
#
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

# frozen_string_literal: true

# == Schema Information
#
# Table name: user_tokens
#
#  id           :bigint           not null, primary key
#  device_info  :string
#  expires_at   :datetime         not null
#  revoked_at   :datetime
#  token_digest :string           not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  user_id      :bigint           not null
#
# Indexes
#
#  index_user_tokens_on_token_digest  (token_digest) UNIQUE
#  index_user_tokens_on_user_id       (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
require "digest"
require "securerandom"

class UserToken < ApplicationRecord
  MAX_DEVICE_INFO_LENGTH = 255

  belongs_to :user

  before_validation :truncate_device_info

  scope :active, -> { where(revoked_at: nil).where("expires_at > ?", Time.current) }

  def active?
    !revoked? && !expired?
  end

  def revoked?
    revoked_at.present?
  end

  def expired?
    expires_at <= Time.current
  end

  def revoke!
    update!(revoked_at: Time.current)
  end

  def rotate!(new_device_info: nil)
    new_raw_token = self.class.generate_token
    attrs = {
      token_digest: self.class.digest(new_raw_token),
      expires_at: 30.days.from_now
    }
    attrs[:device_info] = self.class.sanitize_device_info(new_device_info) if new_device_info.present?
    update!(attrs)
    new_raw_token
  end

  class << self
    def digest(token)
      Digest::SHA256.hexdigest(token.to_s)
    end

    def generate_token
      SecureRandom.hex(32)
    end

    def sanitize_device_info(info)
      info.to_s[0, MAX_DEVICE_INFO_LENGTH] if info.present?
    end

    def create_for_user!(user, device_info: nil)
      raw_token = generate_token
      record = create!(
        user: user,
        token_digest: digest(raw_token),
        device_info: sanitize_device_info(device_info),
        expires_at: 30.days.from_now
      )
      [ record, raw_token ]
    end
  end

  private

  def truncate_device_info
    self.device_info = self.class.sanitize_device_info(device_info) if device_info.present?
  end
end

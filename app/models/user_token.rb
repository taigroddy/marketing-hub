# frozen_string_literal: true

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

# frozen_string_literal: true

class PlatformAccount < ApplicationRecord
  belongs_to :user
  has_many :platform_campaigns, dependent: :destroy
  has_many :campaigns, through: :platform_campaigns

  encrypts :access_token
  encrypts :refresh_token

  scope :connected, -> { where(status: "connected") }

  def connected?
    status == "connected"
  end

  def expired?
    token_expires_at.present? && token_expires_at < Time.current
  end

  def platform_name
    type.to_s.demodulize
  end
end

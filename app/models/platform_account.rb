# frozen_string_literal: true

class PlatformAccount < ApplicationRecord
  belongs_to :user

  encrypts :access_token
  encrypts :refresh_token

  validates :type, presence: true
  validates :account_id, presence: true, uniqueness: { scope: [ :user_id, :type ] }
  validates :access_token, presence: true
  validates :status, presence: true

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

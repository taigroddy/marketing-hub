# frozen_string_literal: true

# == Schema Information
#
# Table name: platform_accounts
#
#  id                       :bigint           not null, primary key
#  access_token             :text             not null
#  name                     :string
#  refresh_token            :text
#  refresh_token_expires_at :datetime
#  status                   :string           default("connected"), not null
#  token_expires_at         :datetime
#  type                     :string           not null
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  account_id               :string           not null
#  user_id                  :bigint           not null
#
# Indexes
#
#  index_platform_accounts_on_type                             (type)
#  index_platform_accounts_on_user_id                          (user_id)
#  index_platform_accounts_on_user_id_and_type_and_account_id  (user_id,type,account_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
class PlatformAccount < ApplicationRecord
  default_scope { where(user_id: Current.user&.id) }

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

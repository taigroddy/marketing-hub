# frozen_string_literal: true

class Campaign < ApplicationRecord
  default_scope { where(user_id: Current.user&.id) }

  belongs_to :user
  has_many :platform_campaigns, dependent: :destroy
  has_many :platform_accounts, through: :platform_campaigns
end

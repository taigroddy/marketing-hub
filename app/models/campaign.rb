# frozen_string_literal: true

# == Schema Information
#
# Table name: campaigns
#
#  id         :bigint           not null, primary key
#  budget     :decimal(12, 2)   not null
#  name       :string           not null
#  objective  :string           not null
#  status     :string           default("draft"), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  user_id    :bigint           not null
#
# Indexes
#
#  index_campaigns_on_user_id                 (user_id)
#  index_campaigns_on_user_id_and_created_at  (user_id,created_at)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
class Campaign < ApplicationRecord
  default_scope { where(user_id: Current.user&.id) }

  belongs_to :user
  has_many :platform_campaigns, dependent: :destroy
  has_many :platform_accounts, through: :platform_campaigns
end

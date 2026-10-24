# frozen_string_literal: true

class Campaign < ApplicationRecord
  belongs_to :user
  has_many :platform_campaigns, dependent: :destroy
  has_many :platform_accounts, through: :platform_campaigns

  validates :name, presence: true
  validates :objective, presence: true
  validates :budget, presence: true, numericality: { greater_than: 0 }
  validates :status, presence: true, inclusion: { in: %w[draft active paused completed] }
end

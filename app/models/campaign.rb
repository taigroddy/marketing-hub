# frozen_string_literal: true

class Campaign < ApplicationRecord
  belongs_to :user

  validates :name, presence: true
  validates :objective, presence: true
  validates :budget, presence: true, numericality: { greater_than: 0 }
  validates :status, presence: true, inclusion: { in: %w[draft active paused completed] }
end

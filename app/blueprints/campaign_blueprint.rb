# frozen_string_literal: true

class CampaignBlueprint < ApplicationBlueprint
  identifier :id

  fields :user_id, :name, :objective, :budget, :status, :created_at, :updated_at
end

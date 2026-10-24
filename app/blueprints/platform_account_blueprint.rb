# frozen_string_literal: true

class PlatformAccountBlueprint < ApplicationBlueprint
  identifier :id

  fields :user_id, :type, :account_id, :name, :status, :token_expires_at, :refresh_token_expires_at, :created_at, :updated_at
end

# frozen_string_literal: true

class UserBlueprint < ApplicationBlueprint
  identifier :id

  fields :email, :confirmed_at, :created_at, :updated_at
end

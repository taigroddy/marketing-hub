# frozen_string_literal: true

class CreateCampaigns < ActiveRecord::Migration[8.0]
  def change
    create_table :campaigns do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.string :objective, null: false
      t.decimal :budget, precision: 12, scale: 2, null: false
      t.string :status, null: false, default: "draft"

      t.timestamps
    end

    add_index :campaigns, [ :user_id, :created_at ]
  end
end

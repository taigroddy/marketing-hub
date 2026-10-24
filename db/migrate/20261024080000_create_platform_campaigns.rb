# frozen_string_literal: true

class CreatePlatformCampaigns < ActiveRecord::Migration[8.0]
  def change
    create_table :platform_campaigns do |t|
      t.references :campaign, null: false, foreign_key: true, index: true
      t.references :platform_account, null: false, foreign_key: true, index: true
      t.string :external_campaign_id, index: true
      t.datetime :synced_at
      t.string :sync_status, null: false, default: "pending"
      t.text :last_error_message

      t.timestamps
    end

    add_index :platform_campaigns, [ :campaign_id, :platform_account_id ], unique: true
  end
end

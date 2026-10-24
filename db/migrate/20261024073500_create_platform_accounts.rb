# frozen_string_literal: true

class CreatePlatformAccounts < ActiveRecord::Migration[8.0]
  def change
    create_table :platform_accounts do |t|
      t.references :user, null: false, foreign_key: true, index: true
      t.string :type, null: false, index: true
      t.string :account_id, null: false
      t.string :name
      t.text :access_token, null: false
      t.text :refresh_token
      t.datetime :token_expires_at
      t.datetime :refresh_token_expires_at
      t.string :status, null: false, default: "connected"

      t.timestamps
    end

    add_index :platform_accounts, [ :user_id, :type, :account_id ], unique: true
  end
end

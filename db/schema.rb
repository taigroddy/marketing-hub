# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2026_10_24_080000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "campaigns", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "name", null: false
    t.string "objective", null: false
    t.decimal "budget", precision: 12, scale: 2, null: false
    t.string "status", default: "draft", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "created_at"], name: "index_campaigns_on_user_id_and_created_at"
    t.index ["user_id"], name: "index_campaigns_on_user_id"
  end

  create_table "platform_accounts", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "type", null: false
    t.string "account_id", null: false
    t.string "name"
    t.text "access_token", null: false
    t.text "refresh_token"
    t.datetime "token_expires_at"
    t.datetime "refresh_token_expires_at"
    t.string "status", default: "connected", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["type"], name: "index_platform_accounts_on_type"
    t.index ["user_id", "type", "account_id"], name: "index_platform_accounts_on_user_id_and_type_and_account_id", unique: true
    t.index ["user_id"], name: "index_platform_accounts_on_user_id"
  end

  create_table "platform_campaigns", force: :cascade do |t|
    t.bigint "campaign_id", null: false
    t.bigint "platform_account_id", null: false
    t.string "external_campaign_id"
    t.datetime "synced_at"
    t.string "sync_status", default: "pending", null: false
    t.text "last_error_message"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["campaign_id", "platform_account_id"], name: "idx_on_campaign_id_platform_account_id_878baa76ee", unique: true
    t.index ["campaign_id"], name: "index_platform_campaigns_on_campaign_id"
    t.index ["external_campaign_id"], name: "index_platform_campaigns_on_external_campaign_id"
    t.index ["platform_account_id"], name: "index_platform_campaigns_on_platform_account_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", null: false
    t.string "password_digest", null: false
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "campaigns", "users"
  add_foreign_key "platform_accounts", "users"
  add_foreign_key "platform_campaigns", "campaigns"
  add_foreign_key "platform_campaigns", "platform_accounts"
end

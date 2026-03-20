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

ActiveRecord::Schema[8.1].define(version: 2026_03_20_010531) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "action_text_rich_texts", force: :cascade do |t|
    t.text "body"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.datetime "updated_at", null: false
    t.index ["record_type", "record_id", "name"], name: "index_action_text_rich_texts_uniqueness", unique: true
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "articles", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.datetime "published_at"
    t.string "slug", null: false
    t.string "status", default: "draft", null: false
    t.string "title", default: "", null: false
    t.datetime "updated_at", null: false
    t.bigint "website_id", null: false
    t.index ["website_id", "published_at"], name: "index_articles_on_website_id_and_published_at"
    t.index ["website_id", "slug"], name: "index_articles_on_website_id_and_slug", unique: true
    t.index ["website_id", "status"], name: "index_articles_on_website_id_and_status"
    t.index ["website_id"], name: "index_articles_on_website_id"
  end

  create_table "faqs", force: :cascade do |t|
    t.text "answer"
    t.datetime "created_at", null: false
    t.integer "position", default: 0, null: false
    t.datetime "published_at"
    t.string "question", default: "", null: false
    t.string "slug", null: false
    t.string "status", default: "draft", null: false
    t.datetime "updated_at", null: false
    t.bigint "website_id", null: false
    t.index ["website_id", "position"], name: "index_faqs_on_website_id_and_position"
    t.index ["website_id", "slug"], name: "index_faqs_on_website_id_and_slug", unique: true
    t.index ["website_id", "status"], name: "index_faqs_on_website_id_and_status"
    t.index ["website_id"], name: "index_faqs_on_website_id"
  end

  create_table "reviews", force: :cascade do |t|
    t.string "author"
    t.text "content"
    t.datetime "created_at", null: false
    t.integer "position", default: 0, null: false
    t.datetime "published_at"
    t.string "status", default: "draft", null: false
    t.datetime "updated_at", null: false
    t.bigint "website_id", null: false
    t.index ["website_id", "position"], name: "index_reviews_on_website_id_and_position"
    t.index ["website_id", "status"], name: "index_reviews_on_website_id_and_status"
    t.index ["website_id"], name: "index_reviews_on_website_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "name", default: "", null: false
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.string "role", default: "user", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  create_table "websites", force: :cascade do |t|
    t.string "api_token", null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.string "domain", null: false
    t.string "name", default: "", null: false
    t.string "status", default: "active", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["api_token"], name: "index_websites_on_api_token", unique: true
    t.index ["domain"], name: "index_websites_on_domain", unique: true
    t.index ["user_id"], name: "index_websites_on_user_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "articles", "websites"
  add_foreign_key "faqs", "websites"
  add_foreign_key "reviews", "websites"
  add_foreign_key "websites", "users"
end

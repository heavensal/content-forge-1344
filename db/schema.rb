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

ActiveRecord::Schema[8.1].define(version: 2026_10_27_210000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "action_text_rich_texts", force: :cascade do |t|
    t.string "name", null: false
    t.text "body"
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["record_type", "record_id", "name"], name: "index_action_text_rich_texts_uniqueness", unique: true
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "articles", force: :cascade do |t|
    t.bigint "website_id", null: false
    t.string "title", default: "", null: false
    t.string "slug", null: false
    t.text "description"
    t.string "status", default: "draft", null: false
    t.datetime "published_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "locale", default: "fr", null: false
    t.string "cover_image_public_id"
    t.string "cover_image_url"
    t.index ["cover_image_public_id"], name: "index_articles_on_cover_image_public_id"
    t.index ["website_id", "locale", "slug"], name: "index_articles_on_website_id_and_locale_and_slug", unique: true
    t.index ["website_id", "published_at"], name: "index_articles_on_website_id_and_published_at"
    t.index ["website_id", "status"], name: "index_articles_on_website_id_and_status"
    t.index ["website_id"], name: "index_articles_on_website_id"
  end

  create_table "faqs", force: :cascade do |t|
    t.bigint "website_id", null: false
    t.string "question", default: "", null: false
    t.text "answer"
    t.string "slug", null: false
    t.string "status", default: "draft", null: false
    t.datetime "published_at"
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "locale", default: "fr", null: false
    t.index ["website_id", "locale", "slug"], name: "index_faqs_on_website_id_and_locale_and_slug", unique: true
    t.index ["website_id", "position"], name: "index_faqs_on_website_id_and_position"
    t.index ["website_id", "status"], name: "index_faqs_on_website_id_and_status"
    t.index ["website_id"], name: "index_faqs_on_website_id"
  end

  create_table "mcp_changes", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "website_id", null: false
    t.string "request_key", null: false
    t.string "content_type", null: false
    t.string "operation", null: false
    t.bigint "record_id"
    t.jsonb "payload", default: {}, null: false
    t.string "base_digest"
    t.datetime "expires_at", null: false
    t.datetime "applied_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "request_key"], name: "index_mcp_changes_on_user_id_and_request_key", unique: true
    t.index ["user_id"], name: "index_mcp_changes_on_user_id"
    t.index ["website_id"], name: "index_mcp_changes_on_website_id"
  end

  create_table "oauth_access_grants", force: :cascade do |t|
    t.bigint "resource_owner_id", null: false
    t.bigint "application_id", null: false
    t.string "token", null: false
    t.integer "expires_in", null: false
    t.text "redirect_uri", null: false
    t.string "scopes", default: "", null: false
    t.datetime "created_at", null: false
    t.datetime "revoked_at"
    t.index ["application_id"], name: "index_oauth_access_grants_on_application_id"
    t.index ["resource_owner_id"], name: "index_oauth_access_grants_on_resource_owner_id"
    t.index ["token"], name: "index_oauth_access_grants_on_token", unique: true
  end

  create_table "oauth_access_tokens", force: :cascade do |t|
    t.bigint "resource_owner_id"
    t.bigint "application_id", null: false
    t.string "token", null: false
    t.string "refresh_token"
    t.integer "expires_in"
    t.string "scopes"
    t.datetime "created_at", null: false
    t.datetime "revoked_at"
    t.string "previous_refresh_token", default: "", null: false
    t.index ["application_id"], name: "index_oauth_access_tokens_on_application_id"
    t.index ["refresh_token"], name: "index_oauth_access_tokens_on_refresh_token", unique: true
    t.index ["resource_owner_id"], name: "index_oauth_access_tokens_on_resource_owner_id"
    t.index ["token"], name: "index_oauth_access_tokens_on_token", unique: true
  end

  create_table "oauth_applications", force: :cascade do |t|
    t.string "name", null: false
    t.string "uid", null: false
    t.string "secret", null: false
    t.text "redirect_uri", null: false
    t.string "scopes", default: "", null: false
    t.boolean "confidential", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["uid"], name: "index_oauth_applications_on_uid", unique: true
  end

  create_table "reviews", force: :cascade do |t|
    t.bigint "website_id", null: false
    t.string "author"
    t.text "content"
    t.string "status", default: "draft", null: false
    t.datetime "published_at"
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "rating"
    t.string "locale", default: "fr", null: false
    t.index ["website_id", "locale"], name: "index_reviews_on_website_id_and_locale"
    t.index ["website_id", "position"], name: "index_reviews_on_website_id_and_position"
    t.index ["website_id", "status"], name: "index_reviews_on_website_id_and_status"
    t.index ["website_id"], name: "index_reviews_on_website_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "name", default: "", null: false
    t.string "role", default: "user", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  create_table "website_memberships", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "website_id", null: false
    t.string "role", default: "owner", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_website_memberships_on_user_id", unique: true
    t.index ["website_id"], name: "index_website_memberships_on_website_id"
    t.index ["website_id"], name: "index_website_memberships_one_owner", unique: true, where: "((role)::text = 'owner'::text)"
  end

  create_table "websites", force: :cascade do |t|
    t.string "name", default: "", null: false
    t.string "domain", null: false
    t.string "api_token", null: false
    t.string "status", default: "active", null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "email"
    t.string "rebuild_webhook_url"
    t.string "rebuild_webhook_secret", null: false
    t.string "rebuild_webhook_token"
    t.boolean "imports_articles", default: false, null: false
    t.boolean "imports_faqs", default: false, null: false
    t.boolean "imports_reviews", default: false, null: false
    t.string "default_locale", default: "fr", null: false
    t.index ["api_token"], name: "index_websites_on_api_token", unique: true
    t.index ["domain"], name: "index_websites_on_domain", unique: true
    t.index ["rebuild_webhook_secret"], name: "index_websites_on_rebuild_webhook_secret", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "articles", "websites"
  add_foreign_key "faqs", "websites"
  add_foreign_key "mcp_changes", "users"
  add_foreign_key "mcp_changes", "websites"
  add_foreign_key "oauth_access_grants", "oauth_applications", column: "application_id"
  add_foreign_key "oauth_access_tokens", "oauth_applications", column: "application_id"
  add_foreign_key "reviews", "websites"
  add_foreign_key "website_memberships", "users"
  add_foreign_key "website_memberships", "websites"
end

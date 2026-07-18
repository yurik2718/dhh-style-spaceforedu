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

ActiveRecord::Schema[8.1].define(version: 2026_07_18_044015) do
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

  create_table "conversations", force: :cascade do |t|
    t.datetime "admin_last_read_at"
    t.datetime "created_at", null: false
    t.integer "homologation_request_id", null: false
    t.datetime "last_message_at"
    t.datetime "student_last_read_at"
    t.datetime "updated_at", null: false
    t.index ["homologation_request_id"], name: "index_conversations_on_homologation_request_id", unique: true
    t.index ["last_message_at"], name: "index_conversations_on_last_message_at"
  end

  create_table "document_accesses", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "request_document_id", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.string "via", null: false
    t.index ["request_document_id"], name: "index_document_accesses_on_request_document_id"
    t.index ["user_id"], name: "index_document_accesses_on_user_id"
  end

  create_table "homologation_requests", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.datetime "discarded_at"
    t.text "document_checklist", default: "{}"
    t.string "education_system"
    t.string "language_certificate"
    t.string "language_knowledge"
    t.datetime "payment_confirmed_at"
    t.integer "payment_confirmed_by"
    t.datetime "pipeline_changed_at"
    t.integer "pipeline_changed_by"
    t.text "pipeline_notes"
    t.string "pipeline_stage"
    t.string "plan_key", null: false
    t.boolean "privacy_accepted", default: false, null: false
    t.string "status", default: "draft", null: false
    t.datetime "status_changed_at"
    t.integer "status_changed_by"
    t.string "stripe_payment_intent_id"
    t.string "studies_finished"
    t.string "studies_spain"
    t.string "study_type_spain"
    t.string "subject", null: false
    t.string "university"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.integer "year"
    t.index ["discarded_at"], name: "index_homologation_requests_on_discarded_at"
    t.index ["pipeline_changed_at"], name: "index_homologation_requests_on_pipeline_changed_at"
    t.index ["pipeline_stage"], name: "index_homologation_requests_on_pipeline_stage"
    t.index ["status"], name: "index_homologation_requests_on_status"
    t.index ["updated_at"], name: "index_homologation_requests_on_updated_at"
    t.index ["user_id", "status"], name: "index_homologation_requests_on_user_id_and_status"
    t.index ["user_id"], name: "index_homologation_requests_on_user_id"
    t.check_constraint "plan_key IN ('basico','completo','premium')", name: "valid_plan_key"
    t.check_constraint "status IN ('draft','submitted','in_review','awaiting_reply','awaiting_payment','payment_confirmed','in_progress','resolved','closed','declined')", name: "valid_status"
  end

  create_table "messages", force: :cascade do |t|
    t.text "body", null: false
    t.integer "conversation_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["conversation_id", "created_at"], name: "index_messages_on_conversation_id_and_created_at"
    t.index ["conversation_id"], name: "index_messages_on_conversation_id"
    t.index ["user_id"], name: "index_messages_on_user_id"
  end

  create_table "notifications", force: :cascade do |t|
    t.text "body"
    t.string "body_key"
    t.datetime "created_at", null: false
    t.datetime "emailed_at"
    t.text "i18n_vars"
    t.integer "notifiable_id", null: false
    t.string "notifiable_type", null: false
    t.datetime "read_at"
    t.string "title"
    t.string "title_key"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["notifiable_type", "notifiable_id"], name: "index_notifications_on_notifiable"
    t.index ["user_id", "created_at"], name: "index_notifications_on_user_id_and_created_at"
    t.index ["user_id", "read_at"], name: "index_notifications_on_user_id_and_read_at"
    t.index ["user_id"], name: "index_notifications_on_user_id"
  end

  create_table "push_subscriptions", force: :cascade do |t|
    t.string "auth_key", null: false
    t.datetime "created_at", null: false
    t.text "endpoint", null: false
    t.string "p256dh_key", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["endpoint"], name: "index_push_subscriptions_on_endpoint", unique: true
    t.index ["user_id"], name: "index_push_subscriptions_on_user_id"
  end

  create_table "request_documents", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "homologation_request_id", null: false
    t.string "kind", null: false
    t.datetime "updated_at", null: false
    t.index ["homologation_request_id", "kind"], name: "index_request_documents_on_homologation_request_id_and_kind", unique: true
    t.index ["homologation_request_id"], name: "index_request_documents_on_homologation_request_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "stripe_events", id: :string, force: :cascade do |t|
    t.text "payload", null: false
    t.datetime "received_at", null: false
    t.string "type", null: false
  end

  create_table "users", force: :cascade do |t|
    t.date "birthday"
    t.string "country"
    t.datetime "created_at", null: false
    t.datetime "deletion_requested_at"
    t.datetime "discarded_at"
    t.string "email_address", null: false
    t.string "google_uid"
    t.string "guardian_email"
    t.string "guardian_name"
    t.string "guardian_phone"
    t.string "guardian_whatsapp"
    t.string "identity_card"
    t.boolean "is_minor", default: false, null: false
    t.string "locale", default: "es", null: false
    t.string "name", default: "", null: false
    t.boolean "notification_email", default: true, null: false
    t.boolean "notification_telegram", default: false, null: false
    t.datetime "otp_enabled_at"
    t.integer "otp_last_verified_timestep"
    t.string "otp_secret"
    t.string "passport"
    t.string "password_digest", null: false
    t.string "phone"
    t.datetime "privacy_accepted_at"
    t.string "role", default: "student", null: false
    t.string "stripe_customer_id"
    t.string "telegram_chat_id"
    t.string "telegram_link_token"
    t.datetime "updated_at", null: false
    t.string "whatsapp"
    t.index ["deletion_requested_at"], name: "index_users_on_deletion_requested_at"
    t.index ["discarded_at"], name: "index_users_on_discarded_at"
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
    t.index ["google_uid"], name: "index_users_on_google_uid", unique: true
    t.check_constraint "role IN ('super_admin', 'staff', 'student')", name: "valid_role"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "conversations", "homologation_requests"
  add_foreign_key "document_accesses", "request_documents"
  add_foreign_key "document_accesses", "users"
  add_foreign_key "homologation_requests", "users"
  add_foreign_key "homologation_requests", "users", column: "payment_confirmed_by"
  add_foreign_key "homologation_requests", "users", column: "pipeline_changed_by"
  add_foreign_key "homologation_requests", "users", column: "status_changed_by"
  add_foreign_key "messages", "conversations"
  add_foreign_key "messages", "users"
  add_foreign_key "notifications", "users"
  add_foreign_key "push_subscriptions", "users"
  add_foreign_key "request_documents", "homologation_requests"
  add_foreign_key "sessions", "users"
end

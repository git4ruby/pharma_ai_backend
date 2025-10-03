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

ActiveRecord::Schema[7.1].define(version: 2025_10_03_203553) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pgcrypto"
  enable_extension "plpgsql"

  create_table "audit_logs", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "action", null: false
    t.string "resource_type"
    t.integer "resource_id"
    t.string "ip_address"
    t.text "user_agent"
    t.jsonb "metadata", default: {}
    t.datetime "performed_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["action"], name: "index_audit_logs_on_action"
    t.index ["metadata"], name: "index_audit_logs_on_metadata", using: :gin
    t.index ["performed_at"], name: "index_audit_logs_on_performed_at"
    t.index ["resource_type", "resource_id"], name: "index_audit_logs_on_resource_type_and_resource_id"
    t.index ["resource_type"], name: "index_audit_logs_on_resource_type"
    t.index ["user_id", "performed_at"], name: "index_audit_logs_on_user_id_and_performed_at"
    t.index ["user_id"], name: "index_audit_logs_on_user_id"
  end

  create_table "citations", force: :cascade do |t|
    t.bigint "query_id", null: false
    t.bigint "document_id", null: false
    t.bigint "embedding_id", null: false
    t.float "relevance_score", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["document_id"], name: "index_citations_on_document_id"
    t.index ["embedding_id"], name: "index_citations_on_embedding_id"
    t.index ["query_id", "relevance_score"], name: "index_citations_on_query_id_and_relevance_score"
    t.index ["query_id"], name: "index_citations_on_query_id"
  end

  create_table "documents", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "title", null: false
    t.string "filename", null: false
    t.string "file_path", null: false
    t.string "file_type", null: false
    t.integer "file_size", null: false
    t.boolean "contains_phi", default: false, null: false
    t.string "classification"
    t.string "content_hash", null: false
    t.string "status", default: "pending", null: false
    t.datetime "processed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["contains_phi"], name: "index_documents_on_contains_phi"
    t.index ["content_hash"], name: "index_documents_on_content_hash", unique: true
    t.index ["file_type"], name: "index_documents_on_file_type"
    t.index ["status"], name: "index_documents_on_status"
    t.index ["user_id", "created_at"], name: "index_documents_on_user_id_and_created_at"
    t.index ["user_id"], name: "index_documents_on_user_id"
  end

  create_table "embeddings", force: :cascade do |t|
    t.bigint "document_id", null: false
    t.text "chunk_text", null: false
    t.integer "chunk_index", null: false
    t.text "embedding", null: false
    t.string "embedding_model", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["document_id", "chunk_index"], name: "index_embeddings_on_document_id_and_chunk_index", unique: true
    t.index ["document_id"], name: "index_embeddings_on_document_id"
    t.index ["embedding_model"], name: "index_embeddings_on_embedding_model"
  end

  create_table "queries", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.text "question", null: false
    t.text "answer"
    t.string "status", default: "pending", null: false
    t.float "processing_time"
    t.jsonb "metadata", default: {}
    t.datetime "queried_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["metadata"], name: "index_queries_on_metadata", using: :gin
    t.index ["queried_at"], name: "index_queries_on_queried_at"
    t.index ["status"], name: "index_queries_on_status"
    t.index ["user_id", "queried_at"], name: "index_queries_on_user_id_and_queried_at"
    t.index ["user_id"], name: "index_queries_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string "current_sign_in_ip"
    t.string "last_sign_in_ip"
    t.integer "failed_attempts", default: 0, null: false
    t.string "unlock_token"
    t.datetime "locked_at"
    t.string "first_name", null: false
    t.string "last_name", null: false
    t.integer "role", default: 0, null: false
    t.boolean "active", default: true, null: false
    t.datetime "last_activity_at"
    t.string "jti", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["jti"], name: "index_users_on_jti", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["role"], name: "index_users_on_role"
    t.index ["unlock_token"], name: "index_users_on_unlock_token", unique: true
  end

  add_foreign_key "audit_logs", "users"
  add_foreign_key "citations", "documents"
  add_foreign_key "citations", "embeddings"
  add_foreign_key "citations", "queries"
  add_foreign_key "documents", "users"
  add_foreign_key "embeddings", "documents"
  add_foreign_key "queries", "users"
end

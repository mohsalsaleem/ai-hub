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

ActiveRecord::Schema[8.1].define(version: 2026_09_04_130000) do
  create_table "hub_applications", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.string "minimum_worker_trust", default: "owner", null: false
    t.string "name", null: false
    t.integer "organization_id", null: false
    t.string "slug", null: false
    t.string "token_digest", null: false
    t.string "token_hint"
    t.datetime "updated_at", null: false
    t.integer "worker_pool_id"
    t.index ["organization_id", "slug"], name: "index_hub_applications_on_organization_id_and_slug", unique: true
    t.index ["organization_id"], name: "index_hub_applications_on_organization_id"
    t.index ["token_digest"], name: "index_hub_applications_on_token_digest", unique: true
    t.index ["worker_pool_id"], name: "index_hub_applications_on_worker_pool_id"
  end

  create_table "job_executions", force: :cascade do |t|
    t.string "application_name", null: false
    t.integer "attempt_number", null: false
    t.integer "consumer_organization_id", null: false
    t.string "consumer_organization_name", null: false
    t.datetime "created_at", null: false
    t.string "failure_code"
    t.datetime "finished_at"
    t.bigint "hub_duration_ms"
    t.bigint "input_tokens"
    t.integer "job_id", null: false
    t.string "llm_model"
    t.bigint "model_duration_ms"
    t.string "outcome", default: "running", null: false
    t.bigint "output_tokens"
    t.integer "provider_organization_id", null: false
    t.string "provider_organization_name", null: false
    t.boolean "shared", null: false
    t.datetime "started_at", null: false
    t.string "task_reference", null: false
    t.bigint "total_tokens"
    t.datetime "updated_at", null: false
    t.boolean "usage_reported", default: false, null: false
    t.integer "usage_schema_version"
    t.integer "worker_id"
    t.string "worker_name", null: false
    t.integer "worker_pool_id"
    t.string "worker_pool_name"
    t.index ["consumer_organization_id", "finished_at"], name: "index_executions_on_consumer_and_finished"
    t.index ["consumer_organization_id"], name: "index_job_executions_on_consumer_organization_id"
    t.index ["job_id", "attempt_number"], name: "index_job_executions_on_job_id_and_attempt_number", unique: true
    t.index ["job_id"], name: "index_job_executions_on_job_id"
    t.index ["provider_organization_id", "finished_at"], name: "index_executions_on_provider_and_finished"
    t.index ["provider_organization_id"], name: "index_job_executions_on_provider_organization_id"
    t.index ["shared", "finished_at"], name: "index_job_executions_on_shared_and_finished_at"
    t.index ["worker_id"], name: "index_job_executions_on_worker_id"
    t.index ["worker_pool_id"], name: "index_job_executions_on_worker_pool_id"
  end

  create_table "jobs", force: :cascade do |t|
    t.integer "attempts", default: 0, null: false
    t.datetime "available_at", null: false
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.json "error"
    t.integer "hub_application_id", null: false
    t.string "idempotency_key", null: false
    t.json "input", null: false
    t.string "lease_token_digest"
    t.datetime "leased_until"
    t.integer "max_attempts", default: 5, null: false
    t.string "minimum_worker_trust", default: "owner", null: false
    t.json "output"
    t.integer "priority", default: 0, null: false
    t.string "public_id", null: false
    t.string "routing_pool_name"
    t.string "status", default: "queued", null: false
    t.integer "task_definition_id", null: false
    t.datetime "updated_at", null: false
    t.integer "worker_id"
    t.integer "worker_pool_id"
    t.index ["hub_application_id", "idempotency_key"], name: "index_jobs_on_hub_application_id_and_idempotency_key", unique: true
    t.index ["hub_application_id"], name: "index_jobs_on_hub_application_id"
    t.index ["public_id"], name: "index_jobs_on_public_id", unique: true
    t.index ["status", "available_at", "priority"], name: "index_jobs_for_claiming"
    t.index ["task_definition_id"], name: "index_jobs_on_task_definition_id"
    t.index ["worker_id"], name: "index_jobs_on_worker_id"
    t.index ["worker_pool_id"], name: "index_jobs_on_worker_pool_id"
  end

  create_table "memberships", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "organization_id", null: false
    t.string "role", default: "member", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["organization_id", "user_id"], name: "index_memberships_on_organization_id_and_user_id", unique: true
    t.index ["organization_id"], name: "index_memberships_on_organization_id"
    t.index ["user_id"], name: "index_memberships_on_user_id"
  end

  create_table "organizations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "slug", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_organizations_on_slug", unique: true
  end

  create_table "platform_audit_events", force: :cascade do |t|
    t.string "action", null: false
    t.datetime "created_at", null: false
    t.json "details", default: {}, null: false
    t.integer "platform_operator_id", null: false
    t.string "request_ip"
    t.integer "subject_id", null: false
    t.string "subject_label", null: false
    t.string "subject_type", null: false
    t.datetime "updated_at", null: false
    t.index ["platform_operator_id"], name: "index_platform_audit_events_on_platform_operator_id"
    t.index ["subject_type", "subject_id", "created_at"], name: "index_platform_audits_on_subject"
  end

  create_table "platform_operators", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_platform_operators_on_email_address", unique: true
  end

  create_table "platform_sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.integer "platform_operator_id", null: false
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.index ["platform_operator_id"], name: "index_platform_sessions_on_platform_operator_id"
  end

  create_table "routing_decisions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.json "evidence", default: {}, null: false
    t.integer "job_id", null: false
    t.string "outcome", null: false
    t.string "reason", null: false
    t.datetime "updated_at", null: false
    t.integer "worker_id"
    t.integer "worker_pool_id"
    t.index ["job_id", "created_at"], name: "index_routing_decisions_on_job_id_and_created_at"
    t.index ["job_id"], name: "index_routing_decisions_on_job_id"
    t.index ["worker_id"], name: "index_routing_decisions_on_worker_id"
    t.index ["worker_pool_id"], name: "index_routing_decisions_on_worker_pool_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "task_definitions", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.string "digest", null: false
    t.string "executor", default: "structured_generation", null: false
    t.integer "hub_application_id", null: false
    t.json "input_schema", null: false
    t.text "instructions", null: false
    t.string "key", null: false
    t.json "output_schema", null: false
    t.json "requirements", default: {}, null: false
    t.datetime "updated_at", null: false
    t.integer "version", null: false
    t.index ["digest"], name: "index_task_definitions_on_digest"
    t.index ["hub_application_id", "key", "version"], name: "idx_on_hub_application_id_key_version_68178f3166", unique: true
    t.index ["hub_application_id"], name: "index_task_definitions_on_hub_application_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  create_table "worker_enrollment_grants", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.datetime "revoked_at"
    t.string "token_digest", null: false
    t.string "token_hint"
    t.datetime "updated_at", null: false
    t.datetime "used_at"
    t.integer "worker_id", null: false
    t.index ["expires_at"], name: "index_worker_enrollment_grants_on_expires_at"
    t.index ["token_digest"], name: "index_worker_enrollment_grants_on_token_digest", unique: true
    t.index ["worker_id"], name: "index_worker_enrollment_grants_on_worker_id"
  end

  create_table "worker_identity_events", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.json "details", default: {}, null: false
    t.string "event_type", null: false
    t.string "key_fingerprint"
    t.integer "worker_id", null: false
    t.index ["worker_id", "created_at"], name: "index_worker_identity_events_on_worker_id_and_created_at"
    t.index ["worker_id"], name: "index_worker_identity_events_on_worker_id"
  end

  create_table "worker_pool_access_grants", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "organization_id", null: false
    t.datetime "updated_at", null: false
    t.integer "worker_pool_id", null: false
    t.index ["organization_id"], name: "index_worker_pool_access_grants_on_organization_id"
    t.index ["worker_pool_id", "organization_id"], name: "index_pool_access_grants_on_pool_and_organization", unique: true
    t.index ["worker_pool_id"], name: "index_worker_pool_access_grants_on_worker_pool_id"
  end

  create_table "worker_pool_memberships", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "worker_id", null: false
    t.integer "worker_pool_id", null: false
    t.index ["worker_id"], name: "index_worker_pool_memberships_on_worker_id"
    t.index ["worker_pool_id", "worker_id"], name: "index_worker_pool_memberships_on_worker_pool_id_and_worker_id", unique: true
    t.index ["worker_pool_id"], name: "index_worker_pool_memberships_on_worker_pool_id"
  end

  create_table "worker_pools", force: :cascade do |t|
    t.string "access_mode", default: "private", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "operator_status", default: "not_applicable", null: false
    t.integer "organization_id", null: false
    t.string "slug", null: false
    t.datetime "updated_at", null: false
    t.index ["operator_status"], name: "index_worker_pools_on_operator_status"
    t.index ["organization_id", "slug"], name: "index_worker_pools_on_organization_id_and_slug", unique: true
    t.index ["organization_id"], name: "index_worker_pools_on_organization_id"
  end

  create_table "worker_request_nonces", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "nonce_digest", null: false
    t.datetime "updated_at", null: false
    t.integer "worker_id", null: false
    t.index ["expires_at"], name: "index_worker_request_nonces_on_expires_at"
    t.index ["worker_id", "nonce_digest"], name: "index_worker_request_nonces_on_worker_id_and_nonce_digest", unique: true
    t.index ["worker_id"], name: "index_worker_request_nonces_on_worker_id"
  end

  create_table "workers", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.json "availability_days", default: ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"], null: false
    t.string "availability_ends_at"
    t.string "availability_starts_at"
    t.string "availability_timezone", default: "UTC", null: false
    t.json "capabilities", default: [], null: false
    t.datetime "created_at", null: false
    t.datetime "enrolled_at"
    t.datetime "identity_rotated_at"
    t.string "key_fingerprint"
    t.datetime "last_seen_at"
    t.json "latest_metrics", default: {}, null: false
    t.integer "max_concurrent_jobs", default: 1, null: false
    t.datetime "metrics_reported_at"
    t.string "name", null: false
    t.integer "organization_id", null: false
    t.string "participation_mode", default: "private", null: false
    t.datetime "paused_at"
    t.text "public_key_pem"
    t.string "reported_id"
    t.string "token_digest", null: false
    t.string "token_hint"
    t.string "trust_tier", default: "owner", null: false
    t.datetime "updated_at", null: false
    t.string "version"
    t.index ["key_fingerprint"], name: "index_workers_on_key_fingerprint", unique: true
    t.index ["organization_id"], name: "index_workers_on_organization_id"
    t.index ["token_digest"], name: "index_workers_on_token_digest", unique: true
  end

  add_foreign_key "hub_applications", "organizations"
  add_foreign_key "hub_applications", "worker_pools"
  add_foreign_key "job_executions", "jobs"
  add_foreign_key "job_executions", "organizations", column: "consumer_organization_id"
  add_foreign_key "job_executions", "organizations", column: "provider_organization_id"
  add_foreign_key "job_executions", "worker_pools", on_delete: :nullify
  add_foreign_key "job_executions", "workers", on_delete: :nullify
  add_foreign_key "jobs", "hub_applications"
  add_foreign_key "jobs", "task_definitions"
  add_foreign_key "jobs", "worker_pools", on_delete: :nullify
  add_foreign_key "jobs", "workers"
  add_foreign_key "memberships", "organizations"
  add_foreign_key "memberships", "users"
  add_foreign_key "platform_audit_events", "platform_operators"
  add_foreign_key "platform_sessions", "platform_operators"
  add_foreign_key "routing_decisions", "jobs"
  add_foreign_key "routing_decisions", "worker_pools", on_delete: :nullify
  add_foreign_key "routing_decisions", "workers", on_delete: :nullify
  add_foreign_key "sessions", "users"
  add_foreign_key "task_definitions", "hub_applications"
  add_foreign_key "worker_enrollment_grants", "workers"
  add_foreign_key "worker_identity_events", "workers"
  add_foreign_key "worker_pool_access_grants", "organizations"
  add_foreign_key "worker_pool_access_grants", "worker_pools"
  add_foreign_key "worker_pool_memberships", "worker_pools"
  add_foreign_key "worker_pool_memberships", "workers"
  add_foreign_key "worker_pools", "organizations"
  add_foreign_key "worker_request_nonces", "workers"
  add_foreign_key "workers", "organizations"
end

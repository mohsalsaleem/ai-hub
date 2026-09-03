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

ActiveRecord::Schema[8.1].define(version: 2026_09_03_090000) do
  create_table "hub_applications", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "slug", null: false
    t.string "token_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_hub_applications_on_slug", unique: true
    t.index ["token_digest"], name: "index_hub_applications_on_token_digest", unique: true
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
    t.json "output"
    t.integer "priority", default: 0, null: false
    t.string "public_id", null: false
    t.string "status", default: "queued", null: false
    t.integer "task_definition_id", null: false
    t.datetime "updated_at", null: false
    t.integer "worker_id"
    t.index ["hub_application_id", "idempotency_key"], name: "index_jobs_on_hub_application_id_and_idempotency_key", unique: true
    t.index ["hub_application_id"], name: "index_jobs_on_hub_application_id"
    t.index ["public_id"], name: "index_jobs_on_public_id", unique: true
    t.index ["status", "available_at", "priority"], name: "index_jobs_for_claiming"
    t.index ["task_definition_id"], name: "index_jobs_on_task_definition_id"
    t.index ["worker_id"], name: "index_jobs_on_worker_id"
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
    t.index ["digest"], name: "index_task_definitions_on_digest", unique: true
    t.index ["hub_application_id", "key", "version"], name: "idx_on_hub_application_id_key_version_68178f3166", unique: true
    t.index ["hub_application_id"], name: "index_task_definitions_on_hub_application_id"
  end

  create_table "workers", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.json "capabilities", default: [], null: false
    t.datetime "created_at", null: false
    t.datetime "last_seen_at"
    t.json "latest_metrics", default: {}, null: false
    t.datetime "metrics_reported_at"
    t.string "name", null: false
    t.string "reported_id"
    t.string "token_digest", null: false
    t.datetime "updated_at", null: false
    t.string "version"
    t.index ["token_digest"], name: "index_workers_on_token_digest", unique: true
  end

  add_foreign_key "jobs", "hub_applications"
  add_foreign_key "jobs", "task_definitions"
  add_foreign_key "jobs", "workers"
  add_foreign_key "task_definitions", "hub_applications"
end

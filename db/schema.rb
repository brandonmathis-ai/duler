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

ActiveRecord::Schema[8.1].define(version: 2026_09_12_181107) do
  create_table "assignments", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "location_code"
    t.integer "member_id", null: false
    t.string "role"
    t.datetime "updated_at", null: false
    t.index ["member_id"], name: "index_assignments_on_member_id"
  end

  create_table "import_batches", force: :cascade do |t|
    t.datetime "applied_at"
    t.json "counts"
    t.datetime "created_at", null: false
    t.string "filename"
    t.json "plan"
    t.string "provider"
    t.string "status"
    t.datetime "updated_at", null: false
  end

  create_table "import_records", force: :cascade do |t|
    t.json "after"
    t.json "before"
    t.string "category"
    t.datetime "created_at", null: false
    t.integer "import_batch_id", null: false
    t.string "match_key"
    t.string "matched_member_id"
    t.string "unprocessable_reason"
    t.datetime "updated_at", null: false
    t.index ["category"], name: "index_import_records_on_category"
    t.index ["import_batch_id"], name: "index_import_records_on_import_batch_id"
  end

  create_table "members", force: :cascade do |t|
    t.string "corporate_email"
    t.datetime "created_at", null: false
    t.string "external_id"
    t.string "first_name"
    t.string "invite_status"
    t.string "last_name"
    t.integer "organization_id", null: false
    t.string "status"
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.index ["corporate_email"], name: "index_members_on_corporate_email"
    t.index ["external_id"], name: "index_members_on_external_id"
    t.index ["organization_id", "user_id"], name: "index_members_on_organization_id_and_user_id", unique: true, where: "user_id IS NOT NULL"
    t.index ["organization_id"], name: "index_members_on_organization_id"
    t.index ["user_id"], name: "index_members_on_user_id"
  end

  create_table "organizations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "login_email"
    t.string "personal_email"
    t.datetime "updated_at", null: false
  end

  add_foreign_key "assignments", "members"
  add_foreign_key "import_records", "import_batches"
  add_foreign_key "members", "organizations"
  add_foreign_key "members", "users"
end

# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20170914123057) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "games", force: :cascade do |t|
    t.string "home_team"
    t.string "away_team"
    t.string "result"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "game_id"
    t.string "game_type"
    t.datetime "temp_date"
    t.datetime "game_date"
    t.integer "home_number"
    t.integer "away_number"
    t.string "home_abbr"
    t.string "away_abbr"
  end

  create_table "scores", force: :cascade do |t|
    t.integer "game_id"
    t.string "result"
    t.string "game_status"
    t.integer "home_team_total"
    t.integer "away_team_total"
    t.integer "home_team_rushing"
    t.integer "away_team_rushing"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

end

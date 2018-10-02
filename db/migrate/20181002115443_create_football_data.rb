class CreateFootballData < ActiveRecord::Migration[5.1]
  def change
    create_table :football_data do |t|
      t.string :local_time
      t.integer :year
      t.string :month_day
      t.string :day_week
      t.string :cfb
      t.string :away_team
      t.integer :away_first_quarter_points
      t.integer :away_second_quarter_points
      t.integer :away_first_half_points
      t.integer :away_third_quarter_points
      t.integer :away_forth_quarter_points
      t.integer :away_second_half_points
      t.integer :away_total_points
      t.integer :away_first_half_total_yards
      t.integer :away_first_half_rushing_yards
      t.integer :carries
      t.float :first_half_away_ave_car
      t.float :first_half_away_typc
      t.integer :first_half_away_pass_attempts
      t.integer :first_half_away_pass_completions
      t.float :away_percent_comp
      t.float :first_half_away_ave_yards_pass_attempt
      t.float :first_half_away_typa
      t.integer :away_first_half_total_plays
      t.float :away_first_half_total_plays_yards
      t.float :away_first_half_typp
      t.integer :first_half_away_longest_pass
      t.integer :first_half_away_longest_rush
      t.string :home_team
      t.integer :home_first_quarter_points
      t.integer :home_second_quarter_points
      t.integer :home_first_half_points
      t.integer :home_third_quarter_points
      t.integer :home_forth_quarter_points
      t.integer :home_second_half_points
      t.integer :home_total_points
      t.integer :home_first_half_total_yards
      t.integer :home_first_half_rushing_yards
      t.integer :first_half_home_car
      t.float :first_half_home_ave_car
      t.float :first_half_home_typc
      t.integer :first_half_home_pass_attempts
      t.integer :first_half_home_pass_completions
      t.float :home_percent_comp
      t.float :first_half_home_ave_yards_pass_attempt
      t.float :first_half_home_typa
      t.integer :home_first_half_total_plays
      t.float :home_first_half_total_plays_yards
      t.float :home_first_half_typp
      t.integer :first_half_home_longest_pass
      t.integer :first_half_home_longest_rush
      t.string :second_half_result
      t.float :fg_side_line
      t.float :first_half_side_line
      t.float :second_half_side_line
      t.integer :ah_first_half_diff
      t.integer :ah_second_half_diff
      t.integer :second_half_total_score_ah
      t.float :fg_total_line
      t.float :first_half_total_line
      t.float :second_half_total_line
      t.float :second_half_total_line_one
      t.float :second_half_diff_line
      t.string :second_half_diff_line_string
      t.string :kicked
      t.string :kicked_home_away

      t.integer :game_id
      t.string :game_date
      t.string :home_abbr
      t.string :away_abbr

      t.timestamps
    end
  end
end

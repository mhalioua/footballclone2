class CreateExport < ActiveRecord::Migration[5.1]
  def change
    create_table :exports do |t|
		t.string :home_team
      	t.string :away_team
      	t.integer :game_id
      	t.string :game_date
      	t.string :home_abbr
      	t.string :away_abbr
      	t.string :game_type
      	t.string :time
      	t.integer :year
      	t.string :date
      	t.string :week

      	t.integer :away_first_point
      	t.integer :away_second_point
      	t.integer :away_first_half_point
      	t.integer :away_third_point
      	t.integer :away_forth_point
      	t.integer :away_second_half_point
      	t.integer :away_total_point

	    t.integer :away_team_total
	    t.integer :away_team_rushing
      	t.integer :away_car
	    t.float :away_ave_car
	    t.integer :away_pass_long
	    t.integer :away_rush_long
	    t.integer :away_c
	    t.integer :away_att
	    t.float :away_ave_att
	    t.integer :away_total_play
	    t.float :away_play_yard

	    t.integer :home_first_point
      	t.integer :home_second_point
      	t.integer :home_first_half_point
      	t.integer :home_third_point
      	t.integer :home_forth_point
      	t.integer :home_second_half_point
      	t.integer :home_total_point

	    t.integer :home_team_total
	    t.integer :home_team_rushing
      	t.integer :home_car
	    t.float :home_ave_car
	    t.integer :home_pass_long
	    t.integer :home_rush_long
	    t.integer :home_c
	    t.integer :home_att
	    t.float :home_ave_att
	    t.integer :home_total_play
	    t.float :home_play_yard

	    t.string :stadium
	    t.string :zipcode
	    
      	t.timestamps
    end
  end
end

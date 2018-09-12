class AddLinesTogame < ActiveRecord::Migration[5.1]
  def change
    rename_column :games, :home_pinnacle, :home_full_closer
    rename_column :games, :away_pinnacle, :away_full_closer

    rename_column :games, :home_2nd_pinnacle, :home_second_closer
    rename_column :games, :away_2nd_pinnacle, :away_second_closer

    add_column :games, :home_full_opener, :string
    add_column :games, :away_full_opener, :string

    add_column :games, :home_second_opener, :string
    add_column :games, :away_second_opener, :string

    add_column :games, :home_first_opener, :string
    add_column :games, :away_first_opener, :string

    add_column :games, :home_first_closer, :string
    add_column :games, :away_first_closer, :string
  end
end

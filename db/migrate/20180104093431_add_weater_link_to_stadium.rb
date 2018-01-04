class AddWeaterLinkToStadium < ActiveRecord::Migration[5.1]
  def change
  	add_column :stadia, :weather_link, :string
  end
end

class AddWeatherToExport < ActiveRecord::Migration[5.1]
  def change
  	add_column :exports, :first_temp, :string
  	add_column :exports, :first_dp, :string
  	add_column :exports, :first_humidity, :string
  	add_column :exports, :first_pressure, :string
  	add_column :exports, :first_windspeed, :string
  	add_column :exports, :first_winddirection, :string

  	add_column :exports, :second_temp, :string
  	add_column :exports, :second_dp, :string
  	add_column :exports, :second_humidity, :string
  	add_column :exports, :second_pressure, :string
  	add_column :exports, :second_windspeed, :string
  	add_column :exports, :second_winddirection, :string

  	add_column :exports, :third_temp, :string
  	add_column :exports, :third_dp, :string
  	add_column :exports, :third_humidity, :string
  	add_column :exports, :third_pressure, :string
  	add_column :exports, :third_windspeed, :string
  	add_column :exports, :third_winddirection, :string
  end
end

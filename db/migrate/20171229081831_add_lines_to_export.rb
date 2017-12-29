class AddLinesToExport < ActiveRecord::Migration[5.1]
  def change
  	add_column :exports, :first_side, :float
  	add_column :exports, :second_side, :float
  	add_column :exports, :full_side, :float
  	add_column :exports, :first_total, :float
  	add_column :exports, :second_total, :float
  	add_column :exports, :full_total, :float
  end
end

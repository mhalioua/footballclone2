class AddLinesToExport < ActiveRecord::Migration[5.1]
  def change
  	add_column :stadia, :first_side, :float
  	add_column :stadia, :second_side, :float
  	add_column :stadia, :full_side, :float
  	add_column :stadia, :first_total, :float
  	add_column :stadia, :second_total, :float
  	add_column :stadia, :full_total, :float
  end
end

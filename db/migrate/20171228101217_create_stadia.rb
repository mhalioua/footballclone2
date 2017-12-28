class CreateStadia < ActiveRecord::Migration[5.1]
  def change
    create_table :stadia do |t|
    	t.string :stadium
    	t.string :zipcode
    	t.string :timezone
      t.timestamps
    end
  end
end

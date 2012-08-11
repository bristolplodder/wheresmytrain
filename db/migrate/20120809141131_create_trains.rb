class CreateTrains < ActiveRecord::Migration
  def change
    create_table :trains do |t|
      t.string :name
      t.string :location
      t.string :time
     end
  end
end

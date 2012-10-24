class CreateComments < ActiveRecord::Migration
  def change
    create_table :comments do |t|
      t.string :name
      t.string :location
      t.string :time

      t.timestamps
    end
  end
end

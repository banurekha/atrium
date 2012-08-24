class CreateAtriumEssays < ActiveRecord::Migration
  def self.up
    create_table :atrium_essays do |t|
      t.integer :atrium_description_id, :null=>false
      t.string :content_type
      t.text :content
      t.timestamps
    end
    add_index :atrium_essays, :atrium_description_id
  end

  def self.down
    drop_table :atrium_essays
  end

end

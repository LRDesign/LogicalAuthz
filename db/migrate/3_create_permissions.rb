class CreatePermissions < ActiveRecord::Migration
  def self.up
    create_table :permissions do |perms|
      perms.string :role_name
      perms.integer :role_range_id
      perms.string :controller
      perms.string :action
      perms.integer :subject_id
    end
  end


  def self.down
    drop_table :permissions
  end
end

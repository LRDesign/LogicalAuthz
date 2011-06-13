class CreateRoles < ActiveRecord::Migration
  def self.up
    create_table :roles do |roles|
      roles.integer :authnd_id
      roles.string :role_name
      roles.integer :role_range_id
    end
  end
end

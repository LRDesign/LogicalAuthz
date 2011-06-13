class CreateUsers < ActiveRecord::Migration
  def self.up
    create_table(:users) do |users|
      users.column(:name, :string)
      users.timestamps
    end
  end

  def self.down
    drop_table :users
  end
end

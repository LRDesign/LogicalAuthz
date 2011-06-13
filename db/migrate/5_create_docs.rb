class CreateDocs < ActiveRecord::Migration
  def self.up
    create_table :documents
  end

  def self.down
    drop_table :documents
  end
end

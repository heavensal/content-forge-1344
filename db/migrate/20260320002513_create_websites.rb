# frozen_string_literal: true

class CreateWebsites < ActiveRecord::Migration[8.1]
  def change
    create_table :websites do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false, default: ""
      t.string :domain, null: false
      t.string :api_token, null: false
      t.string :status, null: false, default: "active"
      t.text :description

      t.timestamps
    end

    add_index :websites, :domain, unique: true
    add_index :websites, :api_token, unique: true
  end
end

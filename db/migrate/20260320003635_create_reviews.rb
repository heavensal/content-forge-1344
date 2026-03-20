# frozen_string_literal: true

class CreateReviews < ActiveRecord::Migration[8.1]
  def change
    create_table :reviews do |t|
      t.references :website, null: false, foreign_key: true
      t.string :author
      t.text :content
      t.string :status, null: false, default: "draft"
      t.datetime :published_at
      t.integer :position, null: false, default: 0

      t.timestamps
    end

    add_index :reviews, %i[website_id status]
    add_index :reviews, %i[website_id position]
  end
end

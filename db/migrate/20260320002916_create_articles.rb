# frozen_string_literal: true

class CreateArticles < ActiveRecord::Migration[8.1]
  def change
    create_table :articles do |t|
      t.references :website, null: false, foreign_key: true
      t.string :title, null: false, default: ""
      t.string :slug, null: false
      t.text :description
      t.string :status, null: false, default: "draft"
      t.datetime :published_at

      t.timestamps
    end

    add_index :articles, %i[website_id slug], unique: true
    add_index :articles, %i[website_id status]
    add_index :articles, %i[website_id published_at]
  end
end

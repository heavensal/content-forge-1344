# frozen_string_literal: true

class CreateFaqs < ActiveRecord::Migration[8.1]
  def change
    create_table :faqs do |t|
      t.references :website, null: false, foreign_key: true
      t.string :question, null: false, default: ""
      t.text :answer
      t.string :slug, null: false
      t.string :status, null: false, default: "draft"
      t.datetime :published_at
      t.integer :position, null: false, default: 0

      t.timestamps
    end

    add_index :faqs, %i[website_id slug], unique: true
    add_index :faqs, %i[website_id status]
    add_index :faqs, %i[website_id position]
  end
end

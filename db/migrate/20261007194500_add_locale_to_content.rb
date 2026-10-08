# frozen_string_literal: true

class AddLocaleToContent < ActiveRecord::Migration[8.1]
  def change
    add_column :websites, :default_locale, :string, null: false, default: "fr"

    add_column :articles, :locale, :string, null: false, default: "fr"
    add_column :faqs, :locale, :string, null: false, default: "fr"
    add_column :reviews, :locale, :string, null: false, default: "fr"

    remove_index :articles, column: %i[website_id slug], unique: true
    add_index :articles, %i[website_id locale slug], unique: true

    remove_index :faqs, column: %i[website_id slug], unique: true
    add_index :faqs, %i[website_id locale slug], unique: true

    add_index :reviews, %i[website_id locale]
  end
end

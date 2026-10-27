# frozen_string_literal: true

class AddCoverImageToArticles < ActiveRecord::Migration[8.1]
  def change
    add_column :articles, :cover_image_public_id, :string
    add_column :articles, :cover_image_url, :string
    add_index :articles, :cover_image_public_id
  end
end

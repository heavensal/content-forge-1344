# frozen_string_literal: true

class AddRebuildWebhookToWebsites < ActiveRecord::Migration[8.1]
  def up
    change_table :websites, bulk: true do |t|
      t.string :rebuild_webhook_url
      t.string :rebuild_webhook_secret
      t.string :rebuild_webhook_token
      t.boolean :imports_articles, null: false, default: false
      t.boolean :imports_faqs, null: false, default: false
      t.boolean :imports_reviews, null: false, default: false
    end

    Website.reset_column_information
    Website.where(rebuild_webhook_secret: nil).find_each do |website|
      website.update_column(:rebuild_webhook_secret, SecureRandom.base58(24))
    end

    change_column_null :websites, :rebuild_webhook_secret, false
    add_index :websites, :rebuild_webhook_secret, unique: true
  end

  def down
    remove_index :websites, :rebuild_webhook_secret
    change_table :websites, bulk: true do |t|
      t.remove :rebuild_webhook_url, :rebuild_webhook_secret, :rebuild_webhook_token,
        :imports_articles, :imports_faqs, :imports_reviews
    end
  end
end

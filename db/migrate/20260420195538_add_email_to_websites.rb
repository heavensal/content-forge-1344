class AddEmailToWebsites < ActiveRecord::Migration[8.1]
  def change
    add_column :websites, :email, :string
  end
end

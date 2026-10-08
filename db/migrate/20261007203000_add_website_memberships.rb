# frozen_string_literal: true

class AddWebsiteMemberships < ActiveRecord::Migration[8.1]
  def up
    create_table :website_memberships do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.references :website, null: false, foreign_key: true
      t.string :role, null: false, default: "owner"
      t.timestamps
    end

    add_index :website_memberships, :website_id,
      unique: true,
      where: "role = 'owner'",
      name: "index_website_memberships_one_owner"

    if select_value("SELECT COUNT(*) FROM users").to_i == 1
      # The only account created the existing sites. Admin access comes from users.role,
      # so those sites stay unassigned and can be given to a client later.
      execute "UPDATE users SET role = 'admin'"
    else
      execute <<~SQL.squish
        INSERT INTO website_memberships (user_id, website_id, role, created_at, updated_at)
        SELECT websites.user_id, websites.id, 'owner', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
        FROM websites
        INNER JOIN users ON users.id = websites.user_id
        WHERE users.role <> 'admin'
          AND websites.user_id IN (
            SELECT user_id FROM websites GROUP BY user_id HAVING COUNT(*) = 1
          )
      SQL
    end

    remove_reference :websites, :user, foreign_key: true
  end

  def down
    add_reference :websites, :user, null: true, foreign_key: true

    execute <<~SQL.squish
      UPDATE websites
      SET user_id = website_memberships.user_id
      FROM website_memberships
      WHERE website_memberships.website_id = websites.id
        AND website_memberships.role = 'owner'
    SQL

    execute <<~SQL.squish
      UPDATE websites
      SET user_id = (SELECT id FROM users WHERE role = 'admin' ORDER BY id LIMIT 1)
      WHERE user_id IS NULL
    SQL

    change_column_null :websites, :user_id, false
    drop_table :website_memberships
  end
end

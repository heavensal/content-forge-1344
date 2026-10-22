class CreateMcpIntegration < ActiveRecord::Migration[8.1]
  def change
    create_table :mcp_identities do |t|
      t.references :user, null: false, foreign_key: true
      t.string :issuer, null: false
      t.string :subject, null: false
      t.timestamps
    end
    add_index :mcp_identities, [ :issuer, :subject ], unique: true

    create_table :mcp_changes do |t|
      t.references :user, null: false, foreign_key: true
      t.references :website, null: false, foreign_key: true
      t.string :request_key, null: false
      t.string :content_type, null: false
      t.string :operation, null: false
      t.bigint :record_id
      t.jsonb :payload, null: false, default: {}
      t.string :base_digest
      t.datetime :expires_at, null: false
      t.datetime :applied_at
      t.timestamps
    end
    add_index :mcp_changes, [ :user_id, :request_key ], unique: true
  end
end

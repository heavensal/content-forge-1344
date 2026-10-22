class AddRevokedAtToMcpIdentities < ActiveRecord::Migration[8.1]
  def change
    add_column :mcp_identities, :revoked_at, :datetime
    add_index :mcp_identities, :revoked_at
  end
end

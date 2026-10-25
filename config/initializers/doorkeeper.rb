# OAuth authorization for ChatGPT MCP connections. Devise remains the user login.
Doorkeeper.configure do
  orm :active_record
  base_controller "ApplicationController"
  resource_owner_authenticator do
    current_user || redirect_to(new_user_session_url)
  end
  admin_authenticator do
    head :forbidden
  end
  grant_flows %w[authorization_code]
  force_pkce
  default_scopes :"content:read"
  optional_scopes :"content:write", :"content:publish", :offline_access
  access_token_expires_in 1.hour
  use_refresh_token
  reuse_access_token
  hash_token_secrets
  enforce_content_type
  allow_token_introspection false
end

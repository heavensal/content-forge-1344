module Mcp
  class MetadataController < ActionController::API
    def show
      return head :not_found unless ENV["MCP_ENABLED"] == "true"
      render json: { resource: Settings.resource, authorization_servers: [ Settings.issuer ], scopes_supported: Settings::SCOPES }
    end
  end
end

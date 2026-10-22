module Mcp
  class OauthAuthorizationsController < Doorkeeper::AuthorizationsController
    before_action :require_mcp_resource

    private

    def require_mcp_resource
      return head :not_found unless ENV["MCP_ENABLED"] == "true"
      return if params[:resource] == Settings.resource

      render json: { error: "invalid_target", error_description: "The MCP resource parameter is required." }, status: :bad_request
    end
  end
end

module Mcp
  class OauthTokensController < Doorkeeper::TokensController
    skip_before_action :authenticate_user!, raise: false
    before_action :require_mcp_resource

    private

    def require_mcp_resource
      return head :not_found unless ENV["MCP_ENABLED"] == "true"
      return if params[:resource] == Settings.resource

      render json: { error: "invalid_target", error_description: "The MCP resource parameter is required." }, status: :bad_request
    end
  end
end

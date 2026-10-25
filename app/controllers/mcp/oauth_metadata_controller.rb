module Mcp
  class OauthMetadataController < ActionController::API
    def show
      return head :not_found unless ENV["MCP_ENABLED"] == "true"

      render json: {
        issuer: Settings.issuer,
        authorization_endpoint: "#{Settings.base_url}/oauth/authorize",
        token_endpoint: "#{Settings.base_url}/oauth/token",
        registration_endpoint: "#{Settings.base_url}/oauth/register",
        response_types_supported: [ "code" ],
        grant_types_supported: [ "authorization_code", "refresh_token" ],
        token_endpoint_auth_methods_supported: [ "none" ],
        code_challenge_methods_supported: [ "S256" ],
        scopes_supported: Settings::OAUTH_SCOPES,
        authorization_response_iss_parameter_supported: false
      }
    end
  end
end

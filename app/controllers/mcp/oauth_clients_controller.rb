module Mcp
  class OauthClientsController < ActionController::API
    MAX_BODY_BYTES = 16_384
    RATE_LIMIT_STORE = ActiveSupport::Cache::MemoryStore.new(size: 1.megabyte)
    rate_limit to: 20, within: 1.minute, store: RATE_LIMIT_STORE, name: "oauth-dcr", with: -> { head :too_many_requests }

    def create
      return head :not_found unless ENV["MCP_ENABLED"] == "true"
      return head :unsupported_media_type unless request.media_type == "application/json"
      raw = request.body.read(MAX_BODY_BYTES + 1)
      return head :content_too_large if raw.bytesize > MAX_BODY_BYTES

      body = JSON.parse(raw)
      return render_error("invalid_client_metadata") unless valid_metadata?(body)

      application = Doorkeeper::Application.create!(
        name: body.fetch("client_name", "ChatGPT MCP client").to_s.first(120),
        redirect_uri: body.fetch("redirect_uris").join("\n"),
        scopes: client_scopes(body).join(" "),
        confidential: false
      )
      render json: {
        client_id: application.uid,
        client_id_issued_at: application.created_at.to_i,
        client_name: application.name,
        redirect_uris: application.redirect_uri.split("\n"),
        token_endpoint_auth_method: "none",
        grant_types: [ "authorization_code", "refresh_token" ],
        response_types: [ "code" ],
        scope: application.scopes.to_s
      }, status: :created
    rescue JSON::ParserError, ActiveRecord::RecordInvalid
      render_error("invalid_client_metadata")
    end

    private

    def valid_metadata?(body)
      return false unless body.is_a?(Hash) && body["redirect_uris"].is_a?(Array) && body["redirect_uris"].any? && body["redirect_uris"].length <= 10
      return false unless body["grant_types"].nil? || body["grant_types"] == [ "authorization_code", "refresh_token" ]
      return false unless body["response_types"].nil? || body["response_types"] == [ "code" ]
      return false unless body["token_endpoint_auth_method"].nil? || body["token_endpoint_auth_method"] == "none"
      return false unless body["redirect_uris"].all? { |redirect_uri| redirect_uri.is_a?(String) && valid_redirect_uri?(redirect_uri) }

      scopes = body.fetch("scope", Settings::SCOPES.join(" ")).to_s.split
      scopes.present? && (scopes - Settings::OAUTH_SCOPES).empty?
    end

    def client_scopes(body)
      (body.fetch("scope", Settings::SCOPES.join(" ")).to_s.split + [ "offline_access" ]).uniq
    end

    def valid_redirect_uri?(value)
      uri = URI.parse(value)
      uri.is_a?(URI::HTTPS) && uri.host == "chatgpt.com" && uri.port == 443 && uri.userinfo.nil? &&
        uri.path.match?(%r{\A/(?:connector/oauth/[A-Za-z0-9_-]+|connector_platform_oauth_redirect)\z}) && uri.query.nil? && uri.fragment.nil?
    rescue URI::InvalidURIError, TypeError
      false
    end

    def render_error(error)
      render json: { error: error }, status: :bad_request
    end
  end
end

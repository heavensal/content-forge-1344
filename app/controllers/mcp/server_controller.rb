module Mcp
  class ServerController < ActionController::API
    VERSIONS = %w[2025-06-18 2025-11-25].freeze
    INSTRUCTIONS = "Forge manages articles, customer reviews and FAQs on websites assigned to the signed-in user. First call list_websites to get a website_id. Use list_content/get_content to inspect existing records. Use prepare_change to propose a create, update, delete or publish operation; it never saves or publishes. Show the returned approval_url to the user for review in Forge. A create becomes a draft only after approval. Publishing needs a separate publish proposal and approval. Use get_change to check whether a proposal was applied; applied does not confirm website rebuild delivery. Never invent customer reviews or claim a change was applied before approval.".freeze
    RATE_LIMIT_STORE = ActiveSupport::Cache::MemoryStore.new(size: 8.megabytes)
    before_action :check_enabled
    before_action :check_origin
    rate_limit to: 600, within: 1.minute, store: RATE_LIMIT_STORE, name: "ip", with: :too_many_requests
    before_action :authenticate
    rate_limit to: 120, within: 1.minute, by: -> { @context.user.id }, store: RATE_LIMIT_STORE, name: "user", with: :too_many_requests

    rescue_from Authentication::Unauthorized, with: :unauthorized
    rescue_from Authentication::Unavailable, KeyError do
      render json: { error: "MCP authentication is unavailable" }, status: :service_unavailable
    end

    def show
      response.set_header("Allow", "POST")
      head :method_not_allowed
    end

    def create
      return head :unsupported_media_type unless request.media_type == "application/json"
      accept = request.headers["Accept"].to_s
      return head :not_acceptable unless accept.include?("application/json") && accept.include?("text/event-stream")
      version = request.headers["MCP-Protocol-Version"]
      return head :bad_request if version.present? && !VERSIONS.include?(version)
      raw = request.body.read(262_145)
      return head :content_too_large if raw.bytesize > 262_144
      message = JSON.parse(raw)
      unless message.is_a?(Hash) && message["jsonrpc"] == "2.0" && message["method"].is_a?(String) &&
        (!message.key?("id") || message["id"].is_a?(String) || message["id"].is_a?(Integer))
        return rpc_error(nil, -32600, "Invalid Request")
      end
      return head :bad_request if message["method"] != "initialize" && version.blank?
      id = message["id"]
      unless message.key?("id")
        return head(message["method"].start_with?("notifications/") ? :accepted : :bad_request)
      end
      params = message.fetch("params", {})
      return rpc_error(id, -32602, "Invalid params") unless params.is_a?(Hash)
      result = case message["method"]
      when "initialize"
        { protocolVersion: VERSIONS.include?(params["protocolVersion"]) ? params["protocolVersion"] : VERSIONS.last,
          capabilities: { tools: { listChanged: false } }, serverInfo: { name: "Forge", version: "1.0.0" },
          instructions: INSTRUCTIONS }
      when "ping" then {}
      when "tools/list" then { tools: Tools.definitions }
      when "tools/call" then call_tool(params)
      else return rpc_error(id, -32601, "Method not found")
      end
      render json: { jsonrpc: "2.0", id: id, result: result }
    rescue JSON::ParserError
      rpc_error(nil, -32700, "Parse error")
    end

    private

    def check_enabled
      response.set_header("Cache-Control", "no-store")
      head :not_found unless ENV["MCP_ENABLED"] == "true"
    end

    def check_origin
      origin = request.headers["Origin"]
      allowed = [ Settings.base_url ] + ENV.fetch("MCP_ALLOWED_ORIGINS", "").split(",").map(&:strip)
      head :forbidden if origin.present? && !allowed.include?(origin)
    end

    def too_many_requests
      response.set_header("Retry-After", "60")
      head :too_many_requests
    end

    def authenticate
      @context = Authentication.call(request.authorization)
    end

    def unauthorized
      response.set_header("WWW-Authenticate", "Bearer resource_metadata=\"#{Settings.metadata_url}\", error=\"invalid_token\"")
      render json: { error: "Authentication required" }, status: :unauthorized
    end

    def call_tool(params)
      result = Tools.new(@context).call(params["name"], params.fetch("arguments", {}))
      { content: [ { type: "text", text: JSON.generate(result) } ], isError: false }
    rescue Tools::Forbidden => error
      { content: [ { type: "text", text: error.message } ], isError: true,
        _meta: { "mcp/www_authenticate" => [ "Bearer resource_metadata=\"#{Settings.metadata_url}\", error=\"insufficient_scope\", error_description=\"Authorize the required content scope\", scope=\"#{Settings::SCOPES.join(' ')}\"" ] } }
    rescue ActiveRecord::RecordNotFound
      { content: [ { type: "text", text: "Not found" } ], isError: true }
    rescue ArgumentError, KeyError, ActiveRecord::RecordInvalid => error
      { content: [ { type: "text", text: error.message } ], isError: true }
    end

    def rpc_error(id, code, message)
      render json: { jsonrpc: "2.0", id: id, error: { code: code, message: message } }, status: :bad_request
    end
  end
end

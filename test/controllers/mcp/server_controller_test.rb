require "test_helper"
require_relative "../../support/mcp_method_replacement"

class Mcp::ServerControllerTest < ActionDispatch::IntegrationTest
  include McpMethodReplacement

  setup do
    Mcp::ServerController::RATE_LIMIT_STORE.clear
    ENV["MCP_ENABLED"] = "true"
    ENV["MCP_RESOURCE_URL"] = "https://contentforge.example/mcp"
    @user = User.create!(name: "Protocol", email: "protocol@example.com", password: "password123")
    @site = Website.create!(name: "Protocol", domain: "protocol.example")
    WebsiteMembership.create!(user: @user, website: @site)
    @context = Mcp::Authentication::Context.new(user: @user, scopes: Mcp::Settings::SCOPES)
    @headers = { "CONTENT_TYPE" => "application/json", "ACCEPT" => "application/json, text/event-stream", "Authorization" => "Bearer token", "MCP-Protocol-Version" => "2025-11-25" }
  end

  teardown do
    %w[MCP_ENABLED MCP_RESOURCE_URL].each { |name| ENV.delete(name) }
  end

  test "metadata and unauthenticated challenge support OAuth discovery" do
    get "/.well-known/oauth-protected-resource"
    assert_response :success
    assert_equal ENV["MCP_RESOURCE_URL"], response.parsed_body["resource"]
    post "/mcp", params: "{}", headers: @headers.except("Authorization")
    assert_response :unauthorized
    assert_includes response.headers["WWW-Authenticate"], "oauth-protected-resource"
  end

  test "initialize tools list ping notifications and unsupported streaming" do
    with_method_result(Mcp::Authentication, :call, @context) do
      rpc("initialize", { "protocolVersion" => "2025-11-25" })
      assert_equal "2025-11-25", response.parsed_body.dig("result", "protocolVersion")
      instructions = response.parsed_body.dig("result", "instructions")
      assert_includes instructions.first(512), "approval_url"
      assert_includes instructions, "separate publish proposal"
      rpc("tools/list")
      definitions = response.parsed_body.dig("result", "tools")
      assert_equal 5, definitions.length
      prepare = definitions.find { |tool| tool["name"] == "prepare_change" }
      assert_includes prepare["description"], "does not save or publish"
      assert_includes prepare.dig("inputSchema", "properties", "attributes", "properties", "rating", "description"), "reviews only"
      rpc("ping")
      assert_equal({}, response.parsed_body["result"])
      post "/mcp", params: { jsonrpc: "2.0", method: "notifications/initialized" }.to_json, headers: @headers
      assert_response :accepted
      get "/mcp", headers: @headers
      assert_response :method_not_allowed
    end
  end

  test "invalid origin malformed JSON unknown method oversized body and invalid version" do
    with_method_result(Mcp::Authentication, :call, @context) do
      rpc("ping", {}, headers: @headers.merge("Origin" => "https://attacker.example"))
      assert_response :forbidden
      post "/mcp", params: "{", headers: @headers
      assert_equal(-32700, response.parsed_body.dig("error", "code"))
      rpc("unknown")
      assert_equal(-32601, response.parsed_body.dig("error", "code"))
      post "/mcp", params: "x" * 262_145, headers: @headers
      assert_response :content_too_large
      rpc("ping", {}, headers: @headers.merge("MCP-Protocol-Version" => "bad"))
      assert_response :bad_request
    end
  end

  test "OAuth scopes produce a reauthorization challenge" do
    context = Mcp::Authentication::Context.new(user: @user, scopes: [])
    with_method_result(Mcp::Authentication, :call, context) do
      rpc("tools/call", { "name" => "list_websites", "arguments" => {} })
      assert response.parsed_body.dig("result", "isError")
      assert_includes response.parsed_body.dig("result", "_meta", "mcp/www_authenticate").first, "insufficient_scope"
    end
  end

  test "authenticated approval is required and GET never mutates content" do
    change = McpChange.create!(user: @user, website: @site, request_key: "browser", content_type: "articles", operation: "create", payload: { "title" => "Bird" }, expires_at: 30.minutes.from_now)
    get mcp_change_path(change)
    assert_redirected_to new_user_session_path
    sign_in @user
    assert_no_difference "Article.count" do
      get mcp_change_path(change)
      assert_response :success
    end
    assert_difference "Article.count", 1 do
      patch mcp_change_path(change)
    end
    assert change.reload.applied_at?
  end

  test "approval rejects CSRF and another signed in user" do
    change = McpChange.create!(user: @user, website: @site, request_key: "csrf", content_type: "articles", operation: "create", payload: { "title" => "Bird" }, expires_at: 30.minutes.from_now)
    sign_in @user
    previous = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    assert_no_difference "Article.count" do
      patch mcp_change_path(change)
      assert_response :unprocessable_entity
    end
    ActionController::Base.allow_forgery_protection = previous
    other = User.create!(name: "Other", email: "browser-other@example.com", password: "password123")
    sign_in other
    patch mcp_change_path(change)
    assert_response :not_found
  ensure
    ActionController::Base.allow_forgery_protection = previous
  end

  test "per user rate limit rejects further requests" do
    store = Mcp::ServerController::RATE_LIMIT_STORE
    store.write("rate-limit:mcp/server:user:#{@user.id}", 120)
    with_method_result(Mcp::Authentication, :call, @context) do
      rpc("ping")
      assert_response :too_many_requests
      assert_equal "60", response.headers["Retry-After"]
    end
  end

  test "subsequent messages require a negotiated version header" do
    with_method_result(Mcp::Authentication, :call, @context) do
      rpc("initialize", { "protocolVersion" => "2025-06-18" }, headers: @headers.except("MCP-Protocol-Version"))
      assert_response :success
      rpc("ping", {}, headers: @headers.except("MCP-Protocol-Version"))
      assert_response :bad_request
    end
  end

  test "MCP is disabled by default" do
    ENV.delete("MCP_ENABLED")
    post "/mcp", params: "{}", headers: @headers
    assert_response :not_found
    get "/.well-known/oauth-protected-resource"
    assert_response :not_found
  end

  private

  def rpc(method, params = {}, headers: @headers)
    post "/mcp", params: { jsonrpc: "2.0", id: 1, method: method, params: params }.to_json, headers: headers
  end
end

require "test_helper"
require "cgi"
require "base64"

class Mcp::OauthControllersTest < ActionDispatch::IntegrationTest
  setup do
    ENV["MCP_ENABLED"] = "true"
    ENV["MCP_RESOURCE_URL"] = "https://contentforge.example/mcp"
    sign_in User.create!(name: "OAuth tester", email: "oauth-test@example.com", password: "password123")
  end

  teardown do
    ENV.delete("MCP_ENABLED")
    ENV.delete("MCP_RESOURCE_URL")
  end

  test "OAuth metadata advertises authorization code, PKCE, registration and resource issuer" do
    get "/.well-known/oauth-authorization-server"
    assert_response :success
    assert_equal "https://contentforge.example", response.parsed_body["issuer"]
    assert_equal "https://contentforge.example/oauth/authorize", response.parsed_body["authorization_endpoint"]
    assert_equal "S256", response.parsed_body["code_challenge_methods_supported"].first
    assert_equal "https://contentforge.example/oauth/register", response.parsed_body["registration_endpoint"]
    assert_includes response.parsed_body["scopes_supported"], "offline_access"
  end

  test "protected resource metadata advertises refresh token access scope" do
    get "/.well-known/oauth-protected-resource/mcp"
    assert_response :success
    assert_includes response.parsed_body["scopes_supported"], "offline_access"
  end

  test "dynamic registration accepts ChatGPT public client and rejects arbitrary redirect hosts" do
    payload = {
      client_name: "ChatGPT contentForge",
      redirect_uris: [ "https://chatgpt.com/connector/oauth/callback-123" ],
      grant_types: [ "authorization_code", "refresh_token" ],
      response_types: [ "code" ],
      token_endpoint_auth_method: "none",
      scope: "content:read content:write"
    }
    post "/oauth/register", params: payload.to_json, headers: { "CONTENT_TYPE" => "application/json" }
    assert_response :created
    assert_equal "none", response.parsed_body["token_endpoint_auth_method"]
    assert_equal payload[:redirect_uris], response.parsed_body["redirect_uris"]
    application = Doorkeeper::Application.find_by!(uid: response.parsed_body["client_id"])
    assert_equal %w[content:read content:write offline_access], application.scopes.all

    post "/oauth/register", params: payload.merge(redirect_uris: [ "https://attacker.example/callback" ]).to_json, headers: { "CONTENT_TYPE" => "application/json" }
    assert_response :bad_request
  end

  test "authorization and token endpoints require the exact MCP resource" do
    get "/oauth/authorize", params: { resource: "https://attacker.example/mcp" }
    assert_response :bad_request
    post "/oauth/token", params: { resource: "https://attacker.example/mcp" }
    assert_response :bad_request
  end

  test "existing contentForge account approves a PKCE grant and ChatGPT exchanges it for a scoped token" do
    user = User.create!(name: "Consent tester", email: "consent@example.com", password: "password123")
    sign_in user
    redirect_uri = "https://chatgpt.com/connector/oauth/callback-flow"
    application = Doorkeeper::Application.create!(name: "ChatGPT", redirect_uri: redirect_uri, scopes: Mcp::Settings::OAUTH_SCOPES.join(" "), confidential: false)
    verifier = Base64.urlsafe_encode64(SecureRandom.random_bytes(32), padding: false)
    challenge = Base64.urlsafe_encode64(Digest::SHA256.digest(verifier), padding: false)
    parameters = {
      client_id: application.uid, redirect_uri: redirect_uri, response_type: "code",
      scope: "content:read content:write offline_access", state: "csrf-state-123456789", code_challenge: challenge,
      code_challenge_method: "S256", resource: ENV["MCP_RESOURCE_URL"]
    }

    get "/oauth/authorize", params: parameters
    assert_response :success
    post "/oauth/authorize", params: parameters
    assert_response :redirect
    code = CGI.parse(URI.parse(response.location).query).fetch("code").first

    sign_out user
    post "/oauth/token", params: {
      grant_type: "authorization_code", client_id: application.uid, code: code,
      redirect_uri: redirect_uri, code_verifier: verifier, resource: ENV["MCP_RESOURCE_URL"]
    }
    assert_response :success
    assert response.parsed_body["refresh_token"].present?
    token = response.parsed_body.fetch("access_token")
    access_token = Doorkeeper::AccessToken.by_token(token)
    assert_equal user.id, access_token.resource_owner_id
    assert_equal %w[content:read content:write offline_access], access_token.scopes.to_a
  end

  test "a signed-out customer returns to OAuth consent after their normal contentForge sign-in" do
    user = User.create!(name: "Login tester", email: "login-oauth@example.com", password: "password123")
    sign_out :user
    redirect_uri = "https://chatgpt.com/connector/oauth/login-flow"
    application = Doorkeeper::Application.create!(name: "ChatGPT", redirect_uri: redirect_uri, scopes: "content:read", confidential: false)
    verifier = Base64.urlsafe_encode64(SecureRandom.random_bytes(32), padding: false)
    params = {
      client_id: application.uid, redirect_uri: redirect_uri, response_type: "code", scope: "content:read",
      state: "login-flow-state-123", code_challenge: Base64.urlsafe_encode64(Digest::SHA256.digest(verifier), padding: false),
      code_challenge_method: "S256", resource: ENV["MCP_RESOURCE_URL"]
    }

    get "/oauth/authorize", params: params
    assert_response :redirect
    assert_match %r{/users/sign_in}, response.location

    post "/users/sign_in", params: { user: { email: user.email, password: "password123" } }
    assert_response :redirect
    assert_match %r{/oauth/authorize}, response.location
    follow_redirect!
    assert_response :success
    assert_includes response.body, "Authorize <strong class=\"text-info\">ChatGPT</strong> to use your account?"
  end
end

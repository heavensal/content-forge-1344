require "test_helper"
require_relative "../../support/mcp_method_replacement"

class Mcp::AuthenticationTest < ActiveSupport::TestCase
  include McpMethodReplacement

  setup do
    ENV["MCP_RESOURCE_URL"] = "https://contentforge.example/mcp"
    @user = User.create!(name: "OAuth user", email: "oauth@example.com", password: "password123")
    @application = Doorkeeper::Application.create!(name: "ChatGPT", redirect_uri: "https://chatgpt.com/connector/oauth/test", confidential: false)
    @token = Doorkeeper::AccessToken.create_for(application: @application, resource_owner: @user, scopes: "content:read", expires_in: 1.hour.to_i)
    @raw_token = @token.plaintext_token
  end

  teardown do
    ENV.delete("MCP_RESOURCE_URL")
  end

  test "valid contentForge OAuth token resolves its resource owner and scopes" do
    assert_equal @token, Doorkeeper::AccessToken.by_token(@raw_token)
    assert @token.accessible?
    context = Mcp::Authentication.call("Bearer #{@raw_token}")
    assert_equal @user, context.user
    assert_equal %w[content:read], context.scopes
  end

  test "revoked and expired tokens fail closed" do
    @token.revoke
    assert_raises(Mcp::Authentication::Unauthorized) { Mcp::Authentication.call("Bearer #{@raw_token}") }
    @token.update!(revoked_at: nil, expires_in: 0, created_at: 2.hours.ago)
    assert_raises(Mcp::Authentication::Unauthorized) { Mcp::Authentication.call("Bearer #{@raw_token}") }
  end

  test "another user's token cannot be substituted" do
    assert_raises(Mcp::Authentication::Unauthorized) { Mcp::Authentication.call("Bearer #{SecureRandom.hex(32)}") }
  end

  test "missing or malformed bearer tokens are rejected" do
    [ nil, "token", "Basic token", "Bearer token extra", "Bearer #{'a' * 8193}" ].each do |header|
      assert_raises(Mcp::Authentication::Unauthorized) { Mcp::Authentication.call(header) }
    end
  end
end

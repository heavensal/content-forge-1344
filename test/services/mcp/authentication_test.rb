require "test_helper"
require_relative "../../support/mcp_method_replacement"

class Mcp::AuthenticationTest < ActiveSupport::TestCase
  include McpMethodReplacement

  setup do
    ENV["MCP_RESOURCE_URL"] = "https://contentforge.example/mcp"
    ENV["MCP_OAUTH_ISSUER"] = "https://identity.example"
    @user = User.create!(name: "OAuth user", email: "oauth@example.com", password: "password123")
    @identity = McpIdentity.create!(user: @user, issuer: ENV["MCP_OAUTH_ISSUER"], subject: "stable-subject")
    @claims = { "active" => true, "iss" => ENV["MCP_OAUTH_ISSUER"], "aud" => ENV["MCP_RESOURCE_URL"], "sub" => "stable-subject", "exp" => 10.minutes.from_now.to_i, "scope" => "content:read" }
  end

  teardown do
    ENV.delete("MCP_RESOURCE_URL")
    ENV.delete("MCP_OAUTH_ISSUER")
  end

  test "valid introspection resolves the explicitly linked user" do
    with_method_result(Mcp::Authentication, :introspect, @claims) do
      context = Mcp::Authentication.call("Bearer opaque-token")
      assert_equal @user, context.user
      assert_equal %w[content:read], context.scopes
    end
  end

  test "inactive expired wrong audience wrong issuer missing subject and future tokens fail closed" do
    [ { "active" => false }, { "active" => "true" }, { "exp" => Time.current.to_i }, { "exp" => nil },
      { "aud" => "https://another-resource.example" }, { "iss" => "https://other-issuer.example" },
      { "sub" => nil }, { "nbf" => 10.minutes.from_now.to_i }, { "scope" => nil } ].each do |override|
      with_method_result(Mcp::Authentication, :introspect, @claims.merge(override)) do
        assert_raises(Mcp::Authentication::Unauthorized) { Mcp::Authentication.call("Bearer token") }
      end
    end
  end

  test "email alone cannot link an identity and deleted links stop working" do
    with_method_result(Mcp::Authentication, :introspect, @claims.merge("sub" => "attacker", "email" => @user.email)) do
      assert_raises(Mcp::Authentication::Unauthorized) { Mcp::Authentication.call("Bearer token") }
    end
    @identity.destroy!
    with_method_result(Mcp::Authentication, :introspect, @claims) do
      assert_raises(Mcp::Authentication::Unauthorized) { Mcp::Authentication.call("Bearer token") }
    end
  end

  test "missing or malformed bearer tokens are rejected without introspection" do
    [ nil, "token", "Basic token", "Bearer token extra", "Bearer #{'a' * 8193}" ].each do |header|
      assert_raises(Mcp::Authentication::Unauthorized) { Mcp::Authentication.call(header) }
    end
  end
end

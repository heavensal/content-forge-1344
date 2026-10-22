require "test_helper"
require_relative "../../support/mcp_method_replacement"

class Mcp::IdentitiesControllerTest < ActionDispatch::IntegrationTest
  include McpMethodReplacement

  setup do
    @original_env = %w[MCP_ENABLED MCP_OAUTH_ISSUER MCP_LINK_CLIENT_ID MCP_LINK_CLIENT_SECRET MCP_LINK_REDIRECT_URI].to_h { |key| [ key, ENV[key] ] }
    ENV["MCP_ENABLED"] = "true"
    ENV["MCP_OAUTH_ISSUER"] = "https://identity.example"
    ENV["MCP_LINK_CLIENT_ID"] = "contentforge-link"
    ENV["MCP_LINK_CLIENT_SECRET"] = "link-secret"
    ENV["MCP_LINK_REDIRECT_URI"] = "https://contentforge.example/settings/integrations/mcp/callback"
    @user = User.create!(name: "Account owner", email: "identity-owner@example.com", password: "password123")
    @other = User.create!(name: "Other account", email: "identity-other@example.com", password: "password123")
    sign_in @user
  end

  teardown do
    @original_env.each { |key, value| value ? ENV[key] = value : ENV.delete(key) }
  end

  test "account settings show linked providers and the separate ChatGPT authorization step" do
    get edit_user_registration_path
    assert_response :success
    assert_select "a[href=?]", settings_mcp_identities_path, text: "Manage ChatGPT connection"

    McpIdentity.create!(user: @user, issuer: "https://identity.example", subject: "oidc-sub-1")
    get settings_mcp_identities_path
    assert_response :success
    assert_select "button", text: "Link my ChatGPT sign-in"
    assert_select "li", text: /Sign in to the same account/
  end

  test "linking redirects with PKCE and binds pending state to the signed-in contentForge user" do
    authorization_url = nil
    fake_url = "https://identity.example/authorize?state=returned"
    with_method_result(Mcp::IdentityProvider, :authorization_url, fake_url) do
      post new_mcp_identity_path
      assert_response :redirect
      assert_equal fake_url, response.location
    end
    session = request.session[Mcp::IdentityProvider::IDENTITY_SESSION_KEY]
    assert_equal @user.id, session["user_id"]
    assert_operator session["verifier"].length, :>=, 43
    authorization_url = session["state"]
    assert authorization_url.present?
  end

  test "callback links only the verified issuer and immutable subject to the current account" do
    identity = { issuer: "https://identity.example", subject: "stable-subject" }
    with_method_result(Mcp::IdentityProvider, :exchange_and_identify!, identity) do
      state = start_link
      get mcp_identity_callback_path, params: { code: "one-time-code", state: state, iss: "https://identity.example" }
      assert_redirected_to settings_mcp_identities_path
      assert_equal "stable-subject", @user.mcp_identities.sole.subject
    end
  end

  test "identity already linked to another account cannot be claimed using a matching email" do
    McpIdentity.create!(user: @other, issuer: "https://identity.example", subject: "someone-else")
    with_method_result(Mcp::IdentityProvider, :exchange_and_identify!, { issuer: "https://identity.example", subject: "someone-else" }) do
      state = start_link
      get mcp_identity_callback_path, params: { code: "code", state: state }
      assert_redirected_to settings_mcp_identities_path
      assert_equal @other, McpIdentity.find_by!(issuer: "https://identity.example", subject: "someone-else").user
      assert_empty @user.mcp_identities
    end
  end

  test "wrong state issuer cancelled callback and cross-user callback fail without creating a link" do
    identity = { issuer: "https://identity.example", subject: "victim" }
    with_method_result(Mcp::IdentityProvider, :exchange_and_identify!, identity) do
      state = start_link
      get mcp_identity_callback_path, params: { code: "code", state: "wrong" }
      assert_empty @user.mcp_identities

      state = start_link
      get mcp_identity_callback_path, params: { code: "code", state: state, iss: "https://attacker.example" }
      assert_empty @user.mcp_identities

      state = start_link
      sign_out @user
      sign_in @other
      get mcp_identity_callback_path, params: { code: "code", state: state }
      assert_empty McpIdentity.where(subject: "victim")
    end
  end

  test "cancelled and replayed callbacks cannot create duplicate identities" do
    identity = { issuer: "https://identity.example", subject: "one-time" }
    with_method_result(Mcp::IdentityProvider, :exchange_and_identify!, identity) do
      state = start_link
      get mcp_identity_callback_path, params: { error: "access_denied", state: state }
      assert_empty @user.mcp_identities

      state = start_link
      get mcp_identity_callback_path, params: { code: "code", state: state }
      assert_equal 1, @user.mcp_identities.where(subject: "one-time").count
      get mcp_identity_callback_path, params: { code: "code", state: state }
      assert_equal 1, @user.mcp_identities.where(subject: "one-time").count
    end
  end

  test "unlinked contentForge identity stops authenticating MCP requests" do
    identity = McpIdentity.create!(user: @user, issuer: "https://identity.example", subject: "revoked")
    delete mcp_identity_path(identity)
    assert_redirected_to settings_mcp_identities_path
    assert_equal @user, McpIdentity.find(identity.id).user
    assert_not_nil McpIdentity.find(identity.id).revoked_at
    assert_empty @other.mcp_identities
  end

  test "a revoked provider subject cannot be transferred to another contentForge user" do
    identity = McpIdentity.create!(user: @user, issuer: "https://identity.example", subject: "never-transfer")
    delete mcp_identity_path(identity)
    with_method_result(Mcp::IdentityProvider, :exchange_and_identify!, { issuer: "https://identity.example", subject: "never-transfer" }) do
      sign_out @user
      sign_in @other
      state = start_link
      get mcp_identity_callback_path, params: { code: "code", state: state }
      assert_equal @user, McpIdentity.find(identity.id).user
      assert_not_nil McpIdentity.find(identity.id).revoked_at
    end
  end

  test "connection button stays disabled until the identity provider is configured" do
    %w[MCP_LINK_CLIENT_ID MCP_LINK_CLIENT_SECRET MCP_LINK_REDIRECT_URI].each { |key| ENV.delete(key) }
    get settings_mcp_identities_path
    assert_response :success
    assert_select "button", text: "Link my ChatGPT sign-in", count: 0
        assert_select "p", text: /available after the sign-in provider is configured/
  end

  private

  def start_link
    with_method_result(Mcp::IdentityProvider, :authorization_url, "https://identity.example/authorize") do
      post new_mcp_identity_path
    end
    request.session[Mcp::IdentityProvider::IDENTITY_SESSION_KEY].fetch("state")
  end
end

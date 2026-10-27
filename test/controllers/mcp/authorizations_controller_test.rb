require "test_helper"

class Mcp::AuthorizationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(name: "ChatGPT owner", email: "chatgpt-owner@example.com", password: "password123")
    @application = Doorkeeper::Application.create!(name: "ChatGPT", redirect_uri: "https://chatgpt.com/connector/oauth/test", confidential: false)
    sign_in @user
  end

  test "a Forge account with no grant can open ChatGPT to connect the MCP server" do
    get settings_mcp_authorizations_path

    assert_response :success
    assert_select "h2", text: "Not connected"
    assert_select "a[href=?][target=_blank]", Mcp::Settings::CHATGPT_CONNECTORS_URL, text: "Connect"
    assert_select "button", text: "Disconnect", count: 0
    assert_select "code", text: ENV.fetch("MCP_RESOURCE_URL", "https://forge.1344.fr/mcp")
  end

  test "an expired access token with a refresh token still counts as connected" do
    token = issue_token
    token.update!(created_at: 2.hours.ago, expires_in: 1.hour.to_i)

    get settings_mcp_authorizations_path

    assert_response :success
    assert_select "h2", text: "Connected"
    assert_select "a", text: "Connect", count: 0
    assert_select "button", text: "Disconnect"
  end

  test "disconnect revokes every live grant and the account is no longer connected" do
    first = issue_token
    second = issue_token
    revoked = issue_token
    revoked.revoke

    delete mcp_authorization_path

    assert_redirected_to settings_mcp_authorizations_path
    assert_predicate first.reload, :revoked?
    assert_predicate second.reload, :revoked?
    follow_redirect!
    assert_select "h2", text: "Not connected"
  end

  test "a revoked grant alone is not a connection" do
    issue_token.revoke

    get settings_mcp_authorizations_path

    assert_select "h2", text: "Not connected"
  end

  private

  def issue_token
    Doorkeeper::AccessToken.create_for(
      application: @application,
      resource_owner: @user,
      scopes: "content:read content:write content:publish offline_access",
      expires_in: 1.hour.to_i,
      use_refresh_token: true
    )
  end
end

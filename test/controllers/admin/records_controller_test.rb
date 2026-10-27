# frozen_string_literal: true

require "test_helper"

class Admin::RecordsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = User.create!(email: "admin-#{SecureRandom.hex(4)}@example.com", password: "password123", name: "Admin", role: "admin")
    @client = User.create!(email: "client-#{SecureRandom.hex(4)}@example.com", password: "password123", name: "Client")
    @website = Website.create!(name: "Visible", domain: "visible-#{SecureRandom.hex(4)}.example", email: "hello@visible.example")
    @membership = @client.website_memberships.create!(website: @website, role: "owner")
    @article = @website.articles.create!(title: "Visible article", description: "A note")
    @article.update!(content: "<p>Visible body</p>")
    @faq = @website.faqs.create!(question: "Visible question", answer: "Visible answer")
    @review = @website.reviews.create!(author: "Ada", content: "Visible review", status: "draft")
    @change = McpChange.create!(
      user: @admin,
      website: @website,
      request_key: "change-#{SecureRandom.hex(4)}",
      content_type: "articles",
      operation: "create",
      payload: { "title" => "Visible article" },
      expires_at: 1.hour.from_now
    )
  end

  test "an admin sees each entity table and a user record" do
    sign_in @admin

    get admin_users_path
    assert_response :success
    assert_match @admin.email, response.body
    assert_match @client.email, response.body
    assert_select "td[title=?]", "admin"
    assert_select "td[title=?]", "user"
    assert_not_includes response.body, @admin.encrypted_password
    assert_select "a[href='#{admin_user_path(@client)}']"

    get admin_user_path(@client)
    assert_response :success
    assert_match @client.email, response.body
    assert_match @client.name, response.body
    assert_not_includes response.body, @client.encrypted_password
    assert_not_includes response.body, "encrypted_password"

    get admin_websites_path
    assert_response :success
    assert_match @website.name, response.body
    assert_match @website.domain, response.body
    assert_match @website.api_token, response.body

    get admin_website_path(@website)
    assert_response :success
    assert_match @website.domain, response.body

    get admin_website_memberships_path
    assert_response :success
    assert_match @membership.id.to_s, response.body
    assert_match "owner", response.body

    get admin_articles_path
    assert_response :success
    assert_match "Visible article", response.body
    assert_match "Visible body", response.body

    get admin_article_path(@article)
    assert_response :success
    assert_match "Visible body", response.body

    get admin_faqs_path
    assert_response :success
    assert_match "Visible question", response.body

    get admin_reviews_path
    assert_response :success
    assert_match "Visible review", response.body

    get admin_mcp_changes_path
    assert_response :success
    assert_match @change.request_key, response.body
  end

  test "a user cannot browse the database" do
    sign_in @client

    get admin_users_path
    assert_redirected_to website_path(@website)
    follow_redirect!
    assert_match "Only an admin can browse the database.", response.body

    get admin_user_path(@admin)
    assert_redirected_to website_path(@website)

    get admin_websites_path
    assert_redirected_to website_path(@website)
  end
end

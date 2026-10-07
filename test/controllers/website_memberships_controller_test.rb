# frozen_string_literal: true

require "test_helper"

class WebsiteMembershipsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = User.create!(email: "admin-#{SecureRandom.hex(4)}@example.com", password: "password123", name: "Admin", role: "admin")
    @client = User.create!(email: "client-#{SecureRandom.hex(4)}@example.com", password: "password123", name: "Client")
    @website = Website.create!(name: "Assigned", domain: "assign-#{SecureRandom.hex(4)}.example")
  end

  test "an admin assigns a website and the client cannot create another" do
    sign_in @admin
    post website_memberships_path(@website), params: { email: @client.email.upcase, role: "owner" }

    assert_redirected_to website_path(@website)
    assert @website.website_memberships.owner.exists?(user: @client)

    sign_in @client
    get new_website_path
    assert_redirected_to website_path(@website)
    get website_path(@website)
    assert_response :success
  end

  test "an admin cannot assign a second website to a client who already has one" do
    owned = Website.create!(name: "Owned", domain: "owned-#{SecureRandom.hex(4)}.example")
    @client.website_memberships.create!(website: owned, role: "owner")
    sign_in @admin

    assert_no_difference -> { WebsiteMembership.count } do
      post website_memberships_path(@website), params: { email: @client.email, role: "owner" }
    end
    assert_redirected_to website_path(@website)
    follow_redirect!
    assert_match "already has a website", response.body
  end

  test "a client cannot assign a website" do
    sign_in @client
    post website_memberships_path(@website), params: { email: @client.email, role: "owner" }

    assert_redirected_to websites_path
    assert_not @website.website_memberships.exists?
  end
end

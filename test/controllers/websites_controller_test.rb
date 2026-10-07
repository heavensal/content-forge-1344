# frozen_string_literal: true

require "test_helper"

class WebsitesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = User.create!(email: "admin-#{SecureRandom.hex(4)}@example.com", password: "password123", name: "Admin", role: "admin")
    @client = User.create!(email: "client-#{SecureRandom.hex(4)}@example.com", password: "password123", name: "Client")
    @website = Website.create!(name: "Assigned", domain: "assigned-#{SecureRandom.hex(4)}.example", email: "contact@assigned.example")
    @other = Website.create!(name: "Hidden", domain: "hidden-#{SecureRandom.hex(4)}.example")
  end

  test "an admin creates websites without using up a client seat" do
    sign_in @admin

    assert_difference -> { Website.count }, 2 do
      assert_no_difference -> { WebsiteMembership.count } do
        post websites_path, params: website_params("One", "one-#{SecureRandom.hex(4)}.example")
        post websites_path, params: website_params("Two", "two-#{SecureRandom.hex(4)}.example")
      end
    end

    assert_redirected_to website_path(Website.order(:id).last)
  end

  test "a client creates one website and then stays on it" do
    sign_in @client
    domain = "mine-#{SecureRandom.hex(4)}.example"

    assert_difference -> { WebsiteMembership.owner.count }, 1 do
      post websites_path, params: website_params("Mine", domain)
    end

    website = Website.find_by!(domain: domain)
    assert_redirected_to website_path(website)
    follow_redirect!
    assert_match website.api_token, response.body

    get new_website_path
    assert_redirected_to website_path(website)

    second_domain = "second-#{SecureRandom.hex(4)}.example"
    post websites_path, params: website_params("Second", second_domain)
    assert_redirected_to website_path(website)
    assert_nil Website.find_by(domain: second_domain)
  end

  test "a client only opens the website they belong to" do
    @client.website_memberships.create!(website: @website, role: "owner")
    sign_in @client

    get websites_path
    assert_redirected_to website_path(@website)

    get website_path(@website)
    assert_response :success
    assert_match "contact@assigned.example", response.body
    assert_match @website.api_token, response.body

    get website_path(@other)
    assert_response :not_found
    get website_articles_path(@other)
    assert_response :not_found
    get website_faqs_path(@other)
    assert_response :not_found
    get website_reviews_path(@other)
    assert_response :not_found
    get website_contact_form_integration_path(@other)
    assert_response :not_found

    get website_articles_path(@website)
    assert_response :success
  end

  test "a client cannot delete a website" do
    @client.website_memberships.create!(website: @website, role: "owner")
    sign_in @client

    assert_no_difference -> { Website.count } do
      delete website_path(@website)
    end
    assert_redirected_to website_path(@website)
  end

  private

  def website_params(name, domain)
    { website: { name: name, domain: domain, status: "active" } }
  end
end

# frozen_string_literal: true

require "test_helper"

class WebsiteMembershipTest < ActiveSupport::TestCase
  setup do
    @client = User.create!(email: "client-#{SecureRandom.hex(4)}@example.com", password: "password123", name: "Client")
    @editor = User.create!(email: "editor-#{SecureRandom.hex(4)}@example.com", password: "password123", name: "Editor")
    @admin = User.create!(email: "admin-#{SecureRandom.hex(4)}@example.com", password: "password123", name: "Admin", role: "admin")
    @website = Website.create!(name: "ARM", domain: "member-#{SecureRandom.hex(4)}.example")
    @other = Website.create!(name: "Other", domain: "other-#{SecureRandom.hex(4)}.example")
  end

  test "a client can own one website and not a second" do
    assert @client.website_memberships.create!(website: @website, role: "owner")

    second = @client.website_memberships.build(website: @other, role: "owner")
    assert_not second.valid?
    assert_includes second.errors[:user_id], "already has a website"
    assert_not @client.can_create_website?
  end

  test "an editor seat also uses the client's one website" do
    @client.website_memberships.create!(website: @website, role: "editor")

    second = @client.website_memberships.build(website: @other, role: "owner")
    assert_not second.valid?
  end

  test "a website has one owner and can also have an editor" do
    @client.website_memberships.create!(website: @website, role: "owner")
    assert @editor.website_memberships.create!(website: @website, role: "editor")

    extra_owner = User.create!(email: "owner-#{SecureRandom.hex(4)}@example.com", password: "password123", name: "Other owner")
    membership = extra_owner.website_memberships.build(website: @website, role: "owner")
    assert_not membership.valid?
    assert_includes membership.errors[:website], "already has an owner"
  end

  test "an admin is not given a membership and can still open every website" do
    membership = @admin.website_memberships.build(website: @website, role: "owner")
    assert_not membership.valid?
    assert @admin.can_create_website?
    assert_includes @admin.admin? ? Website.all : @admin.websites, @website
    assert_includes @admin.admin? ? Website.all : @admin.websites, @other
  end
end

require "test_helper"

class Mcp::ToolsTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  include ActionDispatch::TestProcess::FixtureFile

  setup do
    ENV["MCP_RESOURCE_URL"] = "https://forge.example/mcp"
    @user = User.create!(name: "Client", email: "mcp-client@example.com", password: "password123")
    @other = User.create!(name: "Other", email: "mcp-other@example.com", password: "password123")
    @site = Website.create!(name: "Client", domain: "mcp-client.example")
    @foreign = Website.create!(name: "Other", domain: "mcp-other.example")
    WebsiteMembership.create!(user: @user, website: @site)
    WebsiteMembership.create!(user: @other, website: @foreign)
    @tools = tools_for(@user)
  end

  teardown do
    ENV.delete("MCP_RESOURCE_URL")
  end

  test "all three types support staged CRUD and explicit publication" do
    {
      "articles" => { "title" => "Birds", "content" => "<p>Birds fly.</p>" },
      "reviews" => { "author" => "Actual customer", "content" => "Supplied testimonial", "rating" => 5 },
      "faqs" => { "question" => "Do birds fly?", "answer" => "Most do." }
    }.each do |type, attributes|
      records = @site.public_send(type)
      result = prepare(type: type, attributes: attributes)
      assert_equal 0, records.count
      change = McpChange.find(result[:change_id])
      change.apply!(@user)
      record = records.find(change.reload.record_id)
      assert record.draft?
      change.apply!(@user)
      assert_equal 1, records.count

      publication = prepare(type: type, operation: "publish", id: record.id)
      assert record.reload.draft?
      McpChange.find(publication[:change_id]).apply!(@user)
      assert record.reload.published?
      assert records.for_public_api.exists?(record.id)

      field = type == "articles" ? "title" : type == "faqs" ? "question" : "author"
      update = prepare(type: type, operation: "update", id: record.id, attributes: { field => "Revised" })
      assert_not_equal "Revised", record.reload.public_send(field)
      McpChange.find(update[:change_id]).apply!(@user)
      assert_equal "Revised", record.reload.public_send(field)
      deletion = prepare(type: type, operation: "delete", id: record.id)
      assert records.exists?(record.id)
      McpChange.find(deletion[:change_id]).apply!(@user)
      assert_not records.exists?(record.id)
    end
  end

  test "cross client website and record IDs are denied" do
    foreign_article = @foreign.articles.create!(title: "Private")
    assert_raises(ActiveRecord::RecordNotFound) do
      @tools.call("list_content", { "website_id" => @foreign.id, "content_type" => "articles" })
    end
    assert_raises(ActiveRecord::RecordNotFound) do
      prepare(operation: "delete", id: foreign_article.id)
    end
    proposal = McpChange.find(prepare[:change_id])
    assert_raises(ActiveRecord::RecordNotFound) { proposal.apply!(@other) }
    assert_raises(ActiveRecord::RecordNotFound) do
      tools_for(@other).call("get_change", { "change_id" => proposal.id })
    end
  end

  test "revoked membership and archived websites prevent approval" do
    proposal = McpChange.find(prepare[:change_id])
    @user.website_memberships.destroy_all
    assert_raises(ActiveRecord::RecordNotFound) { proposal.apply!(@user) }
    WebsiteMembership.create!(user: @user, website: @site)
    @site.update!(status: "archived")
    assert_raises(ActiveRecord::RecordNotFound) { proposal.apply!(@user) }
  end

  test "read write and publish scopes are enforced" do
    @tools = tools_for(@user, [])
    assert_raises(Mcp::Tools::Forbidden) { @tools.call("list_websites", {}) }
    @tools = tools_for(@user, %w[content:read])
    assert_raises(Mcp::Tools::Forbidden) { prepare }
    record = @site.articles.create!(title: "Public", status: "published", published_at: Time.current)
    @tools = tools_for(@user, %w[content:read content:write])
    %w[update delete publish].each do |operation|
      assert_raises(Mcp::Tools::Forbidden) { prepare(operation: operation, id: record.id) }
    end
  end

  test "publication state and tenant identifiers cannot be mass assigned" do
    %w[status published_at website_id user_id].each do |field|
      assert_raises(ArgumentError) { prepare(attributes: { "title" => "Bird", field => "published" }) }
    end
    assert_raises(ArgumentError) { prepare(attributes: { "title" => [ "bad" ] }) }
    assert_raises(ArgumentError) { prepare(type: "users") }
  end

  test "invalid content is rejected before creating a proposal" do
    assert_no_difference "McpChange.count" do
      assert_raises(ActiveRecord::RecordInvalid) { prepare(type: "reviews", attributes: { "rating" => 6 }) }
    end
    faq = @site.faqs.create!(question: "Empty answer")
    assert_raises(ActiveRecord::RecordInvalid) { prepare(type: "faqs", operation: "publish", id: faq.id) }
  end

  test "stale content and expired proposals are rejected" do
    article = @site.articles.create!(title: "Before")
    change = McpChange.find(prepare(operation: "update", id: article.id, attributes: { "title" => "Proposed" })[:change_id])
    article.update!(title: "Human edit")
    assert_raises(ArgumentError) { change.apply!(@user) }
    assert_equal "Human edit", article.reload.title
    expired = McpChange.find(prepare[:change_id])
    travel 31.minutes do
      assert_raises(ArgumentError) { expired.apply!(@user) }
    end
  end

  test "rich text changes invalidate a prepared publication" do
    article = @site.articles.create!(title: "Bird", content: "Original")
    proposal = McpChange.find(prepare(operation: "publish", id: article.id)[:change_id])
    article.update!(content: "Changed")
    assert_raises(ArgumentError) { proposal.apply!(@user) }
  end

  test "idempotency keys return the same proposal and reject different input" do
    key = SecureRandom.uuid
    first = prepare(key: key)
    assert_equal first, prepare(key: key)
    McpChange.find(first[:change_id]).apply!(@user)
    assert_equal first[:change_id], prepare(key: key)[:change_id]
    assert_raises(ArgumentError) { prepare(key: key, attributes: { "title" => "Different" }) }
  end

  test "chatgpt can set a presentation image and images inside the article" do
    html = '<p>See</p><img src="https://cdn.example/bird.png" alt="Bird">'
    downloaded = false
    stubbing(Mcp::ArticleImages, :download, ->(*) { downloaded = true }) do
      @proposal = McpChange.find(prepare(attributes: {
        "title" => "Birds",
        "content" => html,
        "cover_image_url" => "https://cdn.example/cover.png"
      })[:change_id])
    end
    assert_not downloaded
    assert_equal "https://cdn.example/cover.png", @proposal.payload["cover_image_url"]
    assert_includes @proposal.payload["content"], "https://cdn.example/bird.png"

    urls = []
    stubbing(Mcp::ArticleImages, :download, lambda { |url|
      urls << url
      fixture_file_upload("pixel.png", "image/png")
    }) do
      stubbing(CloudinaryImages, :upload!, lambda { |website:, io:|
        id = urls.one? ? "11111111-1111-4111-8111-111111111111" : "22222222-2222-4222-8222-222222222222"
        CloudinaryImages::Result.new(
          public_id: "forge/#{website.cloudinary_folder}/#{id}",
          url: "https://res.cloudinary.com/demo/image/upload/forge/#{website.cloudinary_folder}/#{id}.png",
          width: 4,
          height: 3
        )
      }) do
        @proposal.apply!(@user)
      end
    end

    article = @site.articles.find(@proposal.reload.record_id)
    assert_equal "forge/client/11111111-1111-4111-8111-111111111111", article.cover_image_public_id
    assert_includes article.public_content_html, "forge/client/22222222-2222-4222-8222-222222222222"
    assert_includes article.public_content_html, 'alt="Bird"'
    assert_not_includes article.public_content_html, "cdn.example"
    shown = @tools.call("get_content", { "website_id" => @site.id, "content_type" => "articles", "record_id" => article.id })
    assert_equal article.cover_image_url, shown["cover_image_url"]
    assert_includes shown["content"], "forge/client/22222222-2222-4222-8222-222222222222"
  end

  test "article image copies run outside the approval locks" do
    change = McpChange.find(prepare[:change_id])
    baseline = McpChange.connection.current_transaction
    seen = nil
    stubbing(Mcp::ArticleImages, :import!, lambda { |_website, attributes|
      seen = McpChange.connection.current_transaction
      attributes
    }) do
      change.apply!(@user)
    end

    assert_same baseline, seen
    assert change.reload.applied_at?
  end

  test "a failed approval does not delete the presentation image" do
    public_id = "forge/client/55555555-5555-4555-8555-555555555555"
    article = @site.articles.create!(
      title: "Cover",
      cover_image_public_id: public_id,
      cover_image_url: "https://res.cloudinary.com/demo/image/upload/#{public_id}.png"
    )
    change = McpChange.find(prepare(operation: "update", id: article.id, attributes: { "cover_image_url" => "" })[:change_id])
    released = []
    change.define_singleton_method(:update!) { |*| raise "approval failed" }

    stubbing(CloudinaryImages, :destroy, ->(id) { released << id }) do
      assert_raises(RuntimeError) { change.apply!(@user) }
    end

    assert_empty released
    assert_equal public_id, article.reload.cover_image_public_id
    assert_nil change.reload.applied_at
  end

  test "chatgpt image urls must be https and an empty presentation image clears it" do
    assert_raises(ArgumentError) { prepare(attributes: { "title" => "Bird", "cover_image_url" => "http://cdn.example/a.png" }) }
    assert_raises(ArgumentError) { prepare(attributes: { "title" => "Bird", "content" => '<img src="javascript:alert(1)">' }) }
    assert_includes Mcp::Tools.definitions.find { |tool| tool[:name] == "prepare_change" }.dig(:inputSchema, :properties, :attributes, :properties).keys, :cover_image_url

    public_id = "forge/client/44444444-4444-4444-8444-444444444444"
    article = @site.articles.create!(title: "Cover", cover_image_public_id: public_id, cover_image_url: "https://res.cloudinary.com/demo/image/upload/#{public_id}.png")
    released = []
    stubbing(CloudinaryImages, :destroy, ->(id) { released << id }) do
      McpChange.find(prepare(operation: "update", id: article.id, attributes: { "cover_image_url" => "" })[:change_id]).apply!(@user)
    end
    assert_nil article.reload.cover_image_url
    assert_nil article.cover_image_public_id
    assert_equal [ public_id ], released
  end

  test "article HTML strips scripts and cross-client Action Text attachments" do
    proposal = McpChange.find(prepare(attributes: { "title" => "Safe", "content" => '<script>alert(1)</script><action-text-attachment sgid="secret"></action-text-attachment><p onclick="bad()">Text</p>' })[:change_id])
    assert_not_includes proposal.payload["content"], "sgid"
    assert_not_includes proposal.payload["content"], "onclick"
    assert_not_includes proposal.payload["content"], "<script"
  end

  test "preparing changes schedules no rebuild; approving uses existing callback" do
    @site.update!(imports_articles: true, rebuild_webhook_url: "https://build.example/hook")
    assert_no_enqueued_jobs do
      @proposal = McpChange.find(prepare[:change_id])
    end
    assert_enqueued_with(job: DeliverWebsiteRebuildJob, args: [ @site.id, "articles" ]) do
      @proposal.apply!(@user)
    end
  end

  test "read responses omit credentials and paginate" do
    result = @tools.call("list_websites", {})
    assert_equal [ @site.id ], result.map { |row| row["id"] }
    assert_not_includes result.to_json, "api_token"
    51.times { |n| @site.articles.create!(title: "Article #{n}") }
    page = @tools.call("list_content", { "website_id" => @site.id, "content_type" => "articles" })
    assert_equal 50, page[:data].length
    rest = @tools.call("list_content", { "website_id" => @site.id, "content_type" => "articles", "after_id" => page[:next_after_id] })
    assert_equal 1, rest[:data].length
  end

  private

  def tools_for(user, scopes = Mcp::Settings::SCOPES)
    Mcp::Tools.new(Mcp::Authentication::Context.new(user: user, scopes: scopes))
  end

  def prepare(type: "articles", operation: "create", id: nil, attributes: nil, key: SecureRandom.uuid)
    args = { "website_id" => @site.id, "content_type" => type, "operation" => operation, "request_key" => key }
    args["record_id"] = id if id
    args["attributes"] = attributes || (operation == "create" ? { "title" => "Bird" } : {})
    @tools.call("prepare_change", args)
  end
end

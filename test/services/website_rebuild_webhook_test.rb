# frozen_string_literal: true

require "test_helper"

class WebsiteRebuildWebhookTest < ActiveSupport::TestCase
  setup do
    user = User.create!(
      email: "hook-#{SecureRandom.hex(4)}@example.com",
      password: "password123",
      name: "Author"
    )
    @website = user.websites.create!(
      name: "ARM",
      domain: "hook-#{SecureRandom.hex(4)}.example",
      rebuild_webhook_url: "https://api.github.com/repos/heavensal/arm-services-astro/dispatches",
      rebuild_webhook_token: "github-pat",
      imports_articles: true
    )
    @website.update_column(:rebuild_webhook_secret, "a" * 24)
    @article = @website.articles.create!(
      title: "Publié",
      status: "published",
      published_at: Time.current
    )
  end

  teardown { WebsiteRebuildWebhook.reset_transport! }

  test "posts a signed github dispatch for an imported article change" do
    request = deliver!("https://api.github.com/repos/heavensal/arm-services-astro/dispatches")

    assert_equal "Bearer github-pat", request["Authorization"]
    assert_equal "application/vnd.github+json", request["Accept"]
    body = JSON.parse(request.body)
    assert_equal "contentforge-rebuild", body["event_type"]
    assert_equal "articles", body.dig("client_payload", "content_type")
    assert_equal @website.domain, body.dig("client_payload", "website", "domain")
    assert_equal @article.updated_at.iso8601, body.dig("client_payload", "updated_at")
    assert_equal "v1=#{signature(request)}", request["X-ContentForge-Signature"]
  end

  test "posts the event itself to a generic https hook and omits a blank token" do
    @website.update!(rebuild_webhook_url: "https://hooks.example.com/rebuild", rebuild_webhook_token: nil)
    request = deliver!("https://hooks.example.com/rebuild")

    assert_nil request["Authorization"]
    body = JSON.parse(request.body)
    assert_equal "content.changed", body["event"]
    assert_equal "articles", body["content_type"]
    assert_equal "v1=#{signature(request)}", request["X-ContentForge-Signature"]
  end

  test "refuses a private address and a client error without calling them twice" do
    WebsiteRebuildWebhook.address_lookup = ->(_host) { [ "127.0.0.1" ] }
    WebsiteRebuildWebhook.connection_for = ->(_uri) { flunk "connected to a private host" }
    assert_raises(WebsiteRebuildWebhook::PermanentError) do
      WebsiteRebuildWebhook.deliver!(@website, "articles")
    end

    http = http_returning(Net::HTTPUnauthorized.new("1.1", "401", "Unauthorized"))
    WebsiteRebuildWebhook.address_lookup = ->(_host) { [ "1.1.1.1" ] }
    WebsiteRebuildWebhook.connection_for = ->(_uri) { http }
    assert_raises(WebsiteRebuildWebhook::PermanentError) do
      WebsiteRebuildWebhook.deliver!(@website, "articles")
    end
  end

  test "retries a server error" do
    http = http_returning(Net::HTTPInternalServerError.new("1.1", "500", "Error"))
    WebsiteRebuildWebhook.address_lookup = ->(_host) { [ "1.1.1.1" ] }
    WebsiteRebuildWebhook.connection_for = ->(_uri) { http }
    assert_raises(WebsiteRebuildWebhook::DeliveryError) do
      WebsiteRebuildWebhook.deliver!(@website, "articles")
    end
  end

  private

  def deliver!(url)
    @website.update!(rebuild_webhook_url: url) unless @website.rebuild_webhook_url == url
    http = RecordingHttp.new
    WebsiteRebuildWebhook.address_lookup = ->(_host) { [ "1.1.1.1" ] }
    WebsiteRebuildWebhook.connection_for = ->(_uri) { http }
    WebsiteRebuildWebhook.deliver!(@website, "articles")
    http.captured
  end

  def signature(request)
    OpenSSL::HMAC.hexdigest(
      "SHA256",
      @website.rebuild_webhook_secret,
      "#{request["X-ContentForge-Timestamp"]}.#{request.body}"
    )
  end

  def http_returning(response)
    http = RecordingHttp.new
    http.response = response
    http
  end

  class RecordingHttp
    attr_accessor :response
    attr_reader :captured

    def use_ssl=(_value); end
    def open_timeout=(_value); end
    def read_timeout=(_value); end
    def max_retries=(_value); end

    def request(request)
      @captured = request
      response || Net::HTTPOK.new("1.1", "204", "No Content")
    end
  end
end

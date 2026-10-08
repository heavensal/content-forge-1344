# frozen_string_literal: true

require "test_helper"

class WebsiteRebuildTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  test "article create update and destroy enqueue a rebuild when articles are imported" do
    website = build_website(imports_articles: true)

    article = nil
    assert_enqueued_with(job: DeliverWebsiteRebuildJob, args: [ website.id, "articles" ]) do
      article = website.articles.create!(title: "Trajet")
    end
    assert_enqueued_with(job: DeliverWebsiteRebuildJob, args: [ website.id, "articles" ]) do
      article.update!(title: "Trajet mis à jour")
    end
    assert_enqueued_with(job: DeliverWebsiteRebuildJob, args: [ website.id, "articles" ]) do
      article.destroy!
    end
  end

  test "faq and review changes enqueue only their own imported type" do
    website = build_website(imports_faqs: true, imports_reviews: true)

    assert_enqueued_with(job: DeliverWebsiteRebuildJob, args: [ website.id, "faqs" ]) do
      website.faqs.create!(question: "Quand ?")
    end
    assert_enqueued_with(job: DeliverWebsiteRebuildJob, args: [ website.id, "reviews" ]) do
      website.reviews.create!(author: "Ada", content: "Bien", rating: 5, status: "published", published_at: Time.current)
    end
    assert_no_enqueued_jobs only: DeliverWebsiteRebuildJob do
      website.articles.create!(title: "Ignoré")
    end
  end

  test "skips the rebuild when the type is not imported, the url is blank, or the site is archived" do
    untouched = build_website
    assert_no_enqueued_jobs only: DeliverWebsiteRebuildJob do
      untouched.articles.create!(title: "Brouillon")
    end

    no_url = build_website(imports_articles: true, rebuild_webhook_url: nil)
    assert_no_enqueued_jobs only: DeliverWebsiteRebuildJob do
      no_url.articles.create!(title: "Sans URL")
    end

    archived = build_website(imports_articles: true, status: "archived")
    assert_no_enqueued_jobs only: DeliverWebsiteRebuildJob do
      archived.articles.create!(title: "Archivé")
    end
  end

  test "rejects a non-https rebuild url" do
    website = Website.new(name: "ARM", domain: "bad-#{SecureRandom.hex(4)}.example", rebuild_webhook_url: "http://example.com/hook")
    assert_not website.valid?
    assert website.errors[:rebuild_webhook_url].present?
  end

  test "job delivers only while the type stays imported" do
    website = build_website(imports_articles: true)
    delivered = []
    original = nil
    original = WebsiteRebuildWebhook.method(:deliver!)
    WebsiteRebuildWebhook.define_singleton_method(:deliver!) do |site, content_type|
      delivered << [ site.id, content_type ]
    end
    DeliverWebsiteRebuildJob.perform_now(website.id, "articles")
    website.update!(imports_articles: false)
    DeliverWebsiteRebuildJob.perform_now(website.id, "articles")
    assert_equal [ [ website.id, "articles" ] ], delivered
  ensure
    if original
      WebsiteRebuildWebhook.define_singleton_method(:deliver!) do |site, content_type|
        original.call(site, content_type)
      end
    end
  end

  private

  def build_website(**attrs)
    Website.create!({
      name: "ARM",
      domain: "rebuild-#{SecureRandom.hex(4)}.example",
      rebuild_webhook_url: "https://api.github.com/repos/heavensal/arm-services-astro/dispatches",
      imports_articles: false,
      imports_faqs: false,
      imports_reviews: false
    }.merge(attrs))
  end
end

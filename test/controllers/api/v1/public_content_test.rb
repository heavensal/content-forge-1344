require "test_helper"

class Api::V1::PublicContentTest < ActionDispatch::IntegrationTest
  setup do
    @website = Website.create!(name: "ARM", domain: "api.example", status: "active")
    @other = Website.create!(name: "Other", domain: "other.example", status: "active")
    @headers = { "Authorization" => "Bearer #{@website.api_token}", "Accept" => "application/json" }
  end

  test "rejects a missing token" do
    get api_v1_reviews_path, headers: { "Accept" => "application/json" }
    assert_response :unauthorized
  end

  test "reviews index is scoped to the token and includes rating" do
    @website.reviews.create!(
      author: "Ada",
      content: "Parfait",
      rating: 4,
      status: "published",
      published_at: 1.day.ago,
      position: 1
    )
    @other.reviews.create!(
      author: "Elsewhere",
      content: "Secret",
      rating: 5,
      status: "published",
      published_at: 1.day.ago
    )

    get api_v1_reviews_path, headers: @headers
    assert_response :success
    body = JSON.parse(response.body)
    assert_equal [ "Ada" ], body["data"].map { |review| review["author"] }
    assert_equal 4, body["data"].first["rating"]
    assert_equal body["data"].first["updated_at"], body["updated_at"]
    assert_equal body["updated_at"], response.headers["X-Content-Updated-At"]
  end

  test "article show returns the published slug and hides drafts and other websites" do
    @website.articles.create!(
      title: "Premier trajet",
      slug: "premier-trajet",
      description: "Résumé",
      status: "published",
      published_at: 1.day.ago
    )
    @website.articles.create!(title: "Brouillon", slug: "brouillon", status: "draft")
    @other.articles.create!(
      title: "Ailleurs",
      slug: "ailleurs",
      status: "published",
      published_at: 1.day.ago
    )

    get api_v1_article_path("premier-trajet"), headers: @headers
    assert_response :success
    body = JSON.parse(response.body)
    assert_equal "premier-trajet", body["slug"]
    assert_equal "Premier trajet", body["title"]
    assert body["updated_at"].present?

    get api_v1_article_path("brouillon"), headers: @headers
    assert_response :not_found

    get api_v1_article_path("ailleurs"), headers: @headers
    assert_response :not_found
  end

  test "locale filter returns that language and falls back to the site default" do
    @website.faqs.create!(
      question: "Français",
      answer: "Oui",
      status: "published",
      published_at: 1.day.ago,
      locale: "fr"
    )
    @website.faqs.create!(
      question: "English",
      answer: "Yes",
      status: "published",
      published_at: 1.day.ago,
      locale: "en"
    )
    @other.faqs.create!(
      question: "Secret",
      answer: "Nope",
      status: "published",
      published_at: 1.day.ago,
      locale: "en"
    )

    get api_v1_faqs_path(locale: "en"), headers: @headers
    assert_response :success
    assert_equal [ "English" ], JSON.parse(response.body)["data"].map { |faq| faq["question"] }

    get api_v1_faqs_path(locale: "fr"), headers: @headers
    assert_equal [ "Français" ], JSON.parse(response.body)["data"].map { |faq| faq["question"] }

    @website.faqs.where(locale: "en").delete_all
    get api_v1_faqs_path(locale: "en"), headers: @headers
    body = JSON.parse(response.body)
    assert_equal [ "Français" ], body["data"].map { |faq| faq["question"] }
    assert_equal "fr", body["data"].first["locale"]
  end

  test "the same article slug can exist in both languages and show falls back to the default" do
    @website.articles.create!(
      title: "Version française",
      slug: "trajet",
      locale: "fr",
      status: "published",
      published_at: 1.day.ago
    )
    @website.articles.create!(
      title: "English version",
      slug: "trajet",
      locale: "en",
      status: "published",
      published_at: 1.day.ago
    )

    get api_v1_article_path("trajet", locale: "en"), headers: @headers
    assert_response :success
    assert_equal "English version", JSON.parse(response.body)["title"]

    @website.articles.where(locale: "en").delete_all
    get api_v1_article_path("trajet", locale: "en"), headers: @headers
    assert_response :success
    body = JSON.parse(response.body)
    assert_equal "Version française", body["title"]
    assert_equal "fr", body["locale"]
  end

  test "a blank content locale uses the website default language" do
    @website.update!(default_locale: "en")
    article = @website.articles.create!(title: "Hello")
    assert_equal "en", article.locale
  end
end

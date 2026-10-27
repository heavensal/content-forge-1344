# frozen_string_literal: true

require "test_helper"

class ArticlesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = User.create!(email: "articles-#{SecureRandom.hex(4)}@example.com", password: "password123", name: "Admin", role: "admin")
    @website = Website.create!(name: "ARM Services", domain: "editor-#{SecureRandom.hex(4)}.example")
    sign_in @admin
  end

  test "the editor offers a presentation image and inline image upload" do
    get new_website_article_path(@website)
    assert_response :success
    assert_match "Presentation image", response.body
    assert_match "cover_image_url", response.body
    assert_match website_article_images_path(@website), response.body
    assert_match "attachment button", response.body
  end

  test "creates an article with a presentation image" do
    stubbing(CloudinaryImages, :upload!, CloudinaryImages::Result.new(
      public_id: "forge/arm-services/55555555-5555-4555-8555-555555555555",
      url: "https://res.cloudinary.com/demo/image/upload/forge/arm-services/55555555-5555-4555-8555-555555555555.png",
      width: 1,
      height: 1
    )) do
      post website_articles_path(@website), params: {
        article: { title: "With image", cover_image: fixture_file_upload("pixel.png", "image/png") }
      }
    end

    article = @website.articles.find_by!(title: "With image")
    assert_redirected_to website_article_path(@website, article)
    assert_equal "forge/arm-services/55555555-5555-4555-8555-555555555555", article.cover_image_public_id
    follow_redirect!
    assert_match article.cover_image_url, response.body
  end

  test "uploads an inline image for the editor" do
    stubbing(CloudinaryImages, :configured?, true) do
      stubbing(Cloudinary::Uploader, :upload, lambda { |_file, options|
        {
          "public_id" => options[:public_id],
          "secure_url" => "https://res.cloudinary.com/demo/image/upload/#{options[:public_id]}.png",
          "width" => 4,
          "height" => 3
        }
      }) do
        post website_article_images_path(@website), params: { image: fixture_file_upload("pixel.png", "image/png") }
      end
    end

    assert_response :success
    body = JSON.parse(response.body)
    assert_match %r{\Aforge/arm-services/[0-9a-f-]{36}\z}, body["public_id"]
    assert_equal "https://res.cloudinary.com/demo/image/upload/#{body["public_id"]}.png", body["url"]
    assert_equal 4, body["width"]
  end

  test "refuses an inline upload for a website the user cannot access" do
    client = User.create!(email: "client-#{SecureRandom.hex(4)}@example.com", password: "password123", name: "Client")
    sign_in client

    post website_article_images_path(@website), params: { image: fixture_file_upload("pixel.png", "image/png") }
    assert_response :not_found
  end
end

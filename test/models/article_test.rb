# frozen_string_literal: true

require "test_helper"

class ArticleTest < ActiveSupport::TestCase
  include ActionDispatch::TestProcess::FixtureFile

  setup do
    @website = Website.create!(name: "ARM Services", domain: "articles-#{SecureRandom.hex(4)}.example")
  end

  test "stores a presentation image and releases the previous one when it is replaced" do
    released = []
    article = @website.articles.create!(
      title: "Cover",
      cover_image_public_id: "forge/arm-services/11111111-1111-4111-8111-111111111111",
      cover_image_url: "https://res.cloudinary.com/demo/image/upload/old.png"
    )

    stubbing(CloudinaryImages, :destroy, ->(public_id) { released << public_id }) do
      stubbing(CloudinaryImages, :upload!, uploaded("22222222-2222-4222-8222-222222222222")) do
        article.cover_image = fixture_file_upload("pixel.png", "image/png")
        assert article.save
      end
    end

    assert_equal "forge/arm-services/22222222-2222-4222-8222-222222222222", article.reload.cover_image_public_id
    assert_equal [ "forge/arm-services/11111111-1111-4111-8111-111111111111" ], released
  end

  test "keeps a presentation image that another article still uses" do
    public_id = "forge/arm-services/33333333-3333-4333-8333-333333333333"
    first = @website.articles.create!(title: "First", cover_image_public_id: public_id, cover_image_url: "https://res.cloudinary.com/demo/old.png")
    @website.articles.create!(title: "Second", cover_image_public_id: public_id, cover_image_url: "https://res.cloudinary.com/demo/old.png")
    released = []

    stubbing(CloudinaryImages, :destroy, ->(id) { released << id }) do
      first.destroy!
    end

    assert_empty released
  end

  test "does not save when the presentation image is rejected" do
    article = @website.articles.build(title: "Nope")
    article.cover_image = fixture_file_upload("note.txt", "text/plain")

    stubbing(CloudinaryImages, :configured?, true) do
      assert_no_difference -> { Article.count } do
        assert_not article.save
      end
    end

    assert_match "JPEG", article.errors.full_messages.join
  end

  test "public html renders cloudinary images and leaves text unchanged" do
    article = @website.articles.create!(title: "Body", description: "Plain")
    article.update!(content: "<div>Intro</div>")
    assert_equal "<div>Intro</div>", article.public_content_html

    url = "https://res.cloudinary.com/demo/image/upload/v1/forge/arm-services/44444444-4444-4444-8444-444444444444.png"
    article.update!(content: %(<action-text-attachment content-type="image/png" url="#{url}" width="12" height="8" caption="Route"></action-text-attachment>))
    html = article.public_content_html

    assert_includes html, %(src="#{url}")
    assert_includes html, 'alt="Route"'
    assert_includes html, 'width="12"'
    assert_not_includes html, "action-text-attachment"

    figure = %(<figure data-trix-attachment='{"contentType":"image/png","url":"#{url}","width":12,"height":8}' data-trix-content-type="image/png"><img src="#{url}"></figure>)
    article.update!(content: figure)
    assert_includes article.public_content_html, %(src="#{url}")
    assert_not_includes article.public_content_html, "action-text-attachment"
  end

  test "public html drops an image whose url is not https" do
    article = @website.articles.create!(title: "Unsafe")
    article.update!(content: '<action-text-attachment content-type="image/png" url="javascript:alert(1)"></action-text-attachment>')
    assert_not_includes article.public_content_html.to_s, "javascript:"
  end

  private

  def uploaded(id)
    CloudinaryImages::Result.new(
      public_id: "forge/arm-services/#{id}",
      url: "https://res.cloudinary.com/demo/image/upload/forge/arm-services/#{id}.png",
      width: 1,
      height: 1
    )
  end
end

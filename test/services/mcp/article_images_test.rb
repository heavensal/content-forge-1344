# frozen_string_literal: true

require "test_helper"

class Mcp::ArticleImagesTest < ActiveSupport::TestCase
  setup do
    @website = Website.create!(name: "ARM Services", domain: "mcp-images-#{SecureRandom.hex(4)}.example")
  end

  teardown do
    Mcp::ArticleImages.address_lookup = nil
    Mcp::ArticleImages.http_get = nil
  end

  test "copies a public https image onto the website cloudinary folder" do
    Mcp::ArticleImages.address_lookup = ->(_host) { [ "93.184.216.34" ] }
    Mcp::ArticleImages.http_get = lambda { |_uri|
      Mcp::ArticleImages::Response.new(code: 200, body: file_fixture("pixel.png").binread, content_type: "image/png", location: nil)
    }
    stubbing(CloudinaryImages, :upload!, lambda { |website:, io:|
      assert_equal "image/png", io.content_type
      assert_equal @website, website
      CloudinaryImages::Result.new(
        public_id: "forge/arm-services/11111111-1111-4111-8111-111111111111",
        url: "https://res.cloudinary.com/demo/image/upload/forge/arm-services/11111111-1111-4111-8111-111111111111.png",
        width: 1,
        height: 1
      )
    }) do
      result = Mcp::ArticleImages.import!(@website, { "cover_image_url" => "https://cdn.example/cover.png" })
      assert_equal "forge/arm-services/11111111-1111-4111-8111-111111111111", result["cover_image_public_id"]
      assert_includes result["cover_image_url"], "forge/arm-services/11111111-1111-4111-8111-111111111111"
    end
  end

  test "does not download an image that already belongs to this website" do
    url = "https://res.cloudinary.com/demo/image/upload/v7/forge/arm-services/33333333-3333-4333-8333-333333333333.png"
    Mcp::ArticleImages.http_get = ->(*) { flunk "downloaded an image Forge already hosts" }
    result = Mcp::ArticleImages.import!(@website, { "content" => %(<p>Hi</p><img src="#{url}" alt="Bird">) })

    assert_includes result["content"], url
    assert_includes result["content"], 'alt="Bird"'
  end

  test "refuses a private address and a redirect toward one" do
    Mcp::ArticleImages.address_lookup = lambda { |host|
      host == "cdn.example" ? [ "93.184.216.34" ] : [ "10.1.1.1" ]
    }
    Mcp::ArticleImages.http_get = lambda { |uri|
      raise "fetched #{uri.host}" unless uri.host == "cdn.example"

      Mcp::ArticleImages::Response.new(code: 302, body: "", content_type: nil, location: "https://intranet.example/secret.png")
    }

    error = assert_raises(Mcp::ArticleImages::Error) do
      Mcp::ArticleImages.import!(@website, { "cover_image_url" => "https://cdn.example/cover.png" })
    end
    assert_equal "Image URL is not public", error.message

    Mcp::ArticleImages.http_get = ->(*) { flunk "fetched a private URL" }
    assert_raises(Mcp::ArticleImages::Error) do
      Mcp::ArticleImages.import!(@website, { "cover_image_url" => "https://intranet.example/secret.png" })
    end
  end
end

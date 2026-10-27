# frozen_string_literal: true

require "test_helper"

class CloudinaryImagesTest < ActiveSupport::TestCase
  include ActionDispatch::TestProcess::FixtureFile

  setup do
    @website = Website.create!(name: "ARM Services", domain: "arm-#{SecureRandom.hex(4)}.example")
  end

  test "uploads under forge/normalized website name/unique id" do
    captured = nil
    with_cloudinary do |calls|
      result = CloudinaryImages.upload!(website: @website, io: fixture_file_upload("pixel.png", "image/png"))
      captured = calls.last
      assert_match %r{\Aforge/arm-services/[0-9a-f-]{36}\z}, result.public_id
      assert_equal "https://res.cloudinary.com/demo/image/upload/#{result.public_id}.png", result.url
      assert_equal 1, result.width
    end

    assert_equal "forge/arm-services", captured[:asset_folder]
    assert_equal captured[:public_id].split("/").last, captured[:display_name]
    assert_equal false, captured[:use_asset_folder_as_public_id_prefix]
  end

  test "retries without the media library folder when the account rejects it" do
    calls = []
    stubbing(CloudinaryImages, :configured?, true) do
      stubbing(Cloudinary::Uploader, :upload, lambda { |_file, options|
        calls << options
        raise CloudinaryException, "asset_folder is not supported" if calls.one?

        upload_response(options[:public_id])
      }) do
        result = CloudinaryImages.upload!(website: @website, io: fixture_file_upload("pixel.png", "image/png"))
        assert_equal calls.first[:public_id], result.public_id
      end
    end

    assert_equal 2, calls.length
    assert_nil calls.last[:asset_folder]
    assert_nil calls.last[:display_name]
  end

  test "rejects a file that is not an image" do
    error = assert_raises(CloudinaryImages::Error) do
      stubbing(CloudinaryImages, :configured?, true) do
        CloudinaryImages.upload!(website: @website, io: fixture_file_upload("note.txt", "text/plain"))
      end
    end
    assert_equal "Use a JPEG, PNG, WebP, or GIF image.", error.message
  end

  test "reports missing credentials before calling Cloudinary" do
    called = false
    stubbing(Cloudinary::Uploader, :upload, ->(*) { called = true }) do
      stubbing(CloudinaryImages, :configured?, false) do
        error = assert_raises(CloudinaryImages::Error) do
          CloudinaryImages.upload!(website: @website, io: fixture_file_upload("pixel.png", "image/png"))
        end
        assert_match "CLOUDINARY_CLOUD_NAME", error.message
      end
    end
    assert_not called
  end

  test "a normalized website name is the cloudinary folder" do
    assert_equal "arm-services", @website.cloudinary_folder
    assert_equal "ecole", Website.new(name: "École").cloudinary_folder
  end

  private

  def with_cloudinary
    calls = []
    stubbing(CloudinaryImages, :configured?, true) do
      stubbing(Cloudinary::Uploader, :upload, lambda { |_file, options|
        calls << options
        upload_response(options[:public_id])
      }) do
        yield calls
      end
    end
  end

  def upload_response(public_id)
    {
      "public_id" => public_id,
      "secure_url" => "https://res.cloudinary.com/demo/image/upload/#{public_id}.png",
      "width" => 1,
      "height" => 1
    }
  end
end

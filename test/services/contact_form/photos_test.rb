require "test_helper"

class ContactForm::PhotosTest < ActiveSupport::TestCase
  TINY_JPEG = "/9j/4AAQSkZJRgABAQEASABIAAD/2wBDAP//////////////////////////////////////////////////////////////////////////////////////wgALCAABAAEBAREA/8QAFBABAAAAAAAAAAAAAAAAAAAAAP/aAAgBAQABPxA="

  test "prepares a jpeg attachment" do
    photos = ContactForm::Photos.prepare([ { "data" => TINY_JPEG } ])

    assert_equal 1, photos.size
    assert_equal "photo-1.jpg", photos.first[:filename]
    assert_equal "image/jpeg", photos.first[:content_type]
    assert photos.first[:data].b.start_with?("\xFF\xD8\xFF".b)
  end

  test "rejects a fourth photo" do
    items = Array.new(4) { { "data" => TINY_JPEG } }

    error = assert_raises(ContactForm::Photos::Rejected) { ContactForm::Photos.prepare(items) }
    assert_equal "Send at most 3 photos.", error.message
  end

  test "rejects a file that is not a jpeg" do
    encoded = Base64.strict_encode64("not-a-photo")

    assert_raises(ContactForm::Photos::Rejected) do
      ContactForm::Photos.prepare([ { "data" => encoded } ])
    end
  end
end

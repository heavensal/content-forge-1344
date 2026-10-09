require "test_helper"

class SiteContactMailerTest < ActionMailer::TestCase
  setup do
    @website = Website.new(name: "ARM Services", domain: "arm.example", email: "contact@arm.example")
  end

  test "fields are the email body, once" do
    mail = SiteContactMailer.forward_inquiry(
      website: @website,
      from_email: "jean@example.com",
      from_name: "Jean Dupont",
      subject: "Contact",
      message: "Bonjour",
      fields: { "nom" => "Dupont", "prénom" => "Jean", "message" => "Bonjour" }
    )

    body = mail.text_part.body.to_s
    assert_equal 1, body.scan("Bonjour").size
    assert_equal 1, body.scan("Dupont").size
    assert_includes body, "prénom"
    refute_includes body, "Jean Dupont"
    assert_equal "jean@example.com", mail.reply_to.first
  end

  test "photos are email attachments" do
    jpeg = Base64.strict_decode64("/9j/4AAQSkZJRgABAQEASABIAAD/2wBDAP//////////////////////////////////////////////////////////////////////////////////////wgALCAABAAEBAREA/8QAFBABAAAAAAAAAAAAAAAAAAAAAP/aAAgBAQABPxA=")
    mail = SiteContactMailer.forward_inquiry(
      website: @website,
      from_email: "jean@example.com",
      fields: { "nom" => "Dupont" },
      photos: [ { filename: "photo-1.jpg", content_type: "image/jpeg", data: jpeg } ]
    )

    assert_equal [ "photo-1.jpg" ], mail.attachments.map(&:filename)
    assert_includes mail.text_part.body.to_s, "Dupont"
  end

  test "message is the body when the site sends no fields" do
    mail = SiteContactMailer.forward_inquiry(
      website: @website,
      from_email: "jean@example.com",
      from_name: "Jean Dupont",
      message: "Bonjour"
    )

    body = mail.text_part.body.to_s
    assert_includes body, "Jean Dupont"
    assert_includes body, "Bonjour"
  end
end

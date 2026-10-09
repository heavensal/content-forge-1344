require "test_helper"

class Api::V1::SendFormControllerTest < ActionDispatch::IntegrationTest
  TINY_JPEG = "/9j/4AAQSkZJRgABAQEASABIAAD/2wBDAP//////////////////////////////////////////////////////////////////////////////////////wgALCAABAAEBAREA/8QAFBABAAAAAAAAAAAAAAAAAAAAAP/aAAgBAQABPxA="

  setup do
    @website = Website.create!(
      name: "ARM",
      domain: "send-form-#{SecureRandom.hex(4)}.example",
      email: "contact@arm.example",
      status: "active"
    )
    @headers = { "Authorization" => "Bearer #{@website.api_token}", "Accept" => "application/json" }
    ActionMailer::Base.delivery_method = :test
    ActionMailer::Base.deliveries.clear
  end

  test "attaches up to three reduced jpeg photos" do
    assert_emails 1 do
      post api_v1_send_form_path, params: {
        from_email: "jean@example.com",
        fields: { nom: "Dupont" },
        attachments: [ { data: TINY_JPEG }, { data: TINY_JPEG } ]
      }, headers: @headers, as: :json
    end

    assert_response :created
    mail = ActionMailer::Base.deliveries.last
    assert_equal [ "photo-1.jpg", "photo-2.jpg" ], mail.attachments.map(&:filename)
    assert_equal 1, mail.text_part.body.to_s.scan("Dupont").size
  end

  test "rejects more than three photos" do
    assert_no_emails do
      post api_v1_send_form_path, params: {
        fields: { nom: "Dupont" },
        attachments: Array.new(4) { { data: TINY_JPEG } }
      }, headers: @headers, as: :json
    end

    assert_response :unprocessable_entity
  end
end

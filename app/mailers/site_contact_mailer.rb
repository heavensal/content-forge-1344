# frozen_string_literal: true

class SiteContactMailer < ApplicationMailer
  def forward_inquiry(website:, from_email: nil, from_name: nil, subject: nil, message: nil, fields: {})
    @website = website
    @from_name = from_name
    @from_email = from_email
    @inquiry_subject = subject.presence
    @message = message.to_s
    @fields = fields.is_a?(Hash) ? fields.stringify_keys : {}

    safe_subject = subject.presence || "Message from #{website.domain}"
    mail(
      to: website.email,
      subject: "[#{website.name}] #{safe_subject}",
      reply_to: from_email.presence
    )
  end
end

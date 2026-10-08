# frozen_string_literal: true

class DeliverWebsiteRebuildJob < ApplicationJob
  queue_as :default

  retry_on WebsiteRebuildWebhook::DeliveryError,
    Timeout::Error,
    SocketError,
    Errno::ECONNREFUSED,
    Errno::EHOSTUNREACH,
    wait: 30.seconds,
    attempts: 4

  discard_on WebsiteRebuildWebhook::PermanentError

  def perform(website_id, content_type)
    website = Website.find_by(id: website_id)
    return if website.nil? || !website.rebuild_for?(content_type)

    WebsiteRebuildWebhook.deliver!(website, content_type)
  end
end

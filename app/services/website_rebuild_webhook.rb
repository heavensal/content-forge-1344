# frozen_string_literal: true

require "ipaddr"
require "json"
require "net/http"
require "openssl"
require "resolv"

class WebsiteRebuildWebhook
  class DeliveryError < StandardError; end
  class PermanentError < StandardError; end

  GITHUB_DISPATCH_PATH = %r{\A/repos/[^/]+/[^/]+/dispatches\z}
  EVENT_TYPE = "contentforge-rebuild"

  class << self
    def deliver!(website, content_type)
      new(website, content_type).deliver!
    end

    def address_lookup
      @address_lookup ||= ->(host) { Resolv.getaddresses(host) }
    end

    attr_writer :address_lookup

    def connection_for
      @connection_for ||= ->(uri) { default_connection(uri) }
    end

    attr_writer :connection_for

    def reset_transport!
      @address_lookup = nil
      @connection_for = nil
    end

    def default_connection(uri)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.open_timeout = 5
      http.read_timeout = 10
      http.max_retries = 0
      http
    end
  end

  def initialize(website, content_type)
    @website = website
    @content_type = content_type.to_s
  end

  def deliver!
    uri = destination_uri
    assert_public_host!(uri)
    body = request_body(uri)
    timestamp = Time.current.to_i.to_s

    http = self.class.connection_for.call(uri)

    request = Net::HTTP::Post.new(uri)
    request["Content-Type"] = "application/json"
    request["User-Agent"] = "ContentForge-Rebuild/1"
    request["X-ContentForge-Timestamp"] = timestamp
    request["X-ContentForge-Signature"] = "v1=#{signature_for(body, timestamp)}"
    request["Authorization"] = "Bearer #{@website.rebuild_webhook_token}" if @website.rebuild_webhook_token.present?
    request["Accept"] = github_dispatch?(uri) ? "application/vnd.github+json" : "application/json"
    request["X-GitHub-Api-Version"] = "2022-11-28" if github_dispatch?(uri)
    request.body = body

    interpret!(http.request(request))
  end

  private

  def destination_uri
    uri = URI.parse(@website.rebuild_webhook_url.to_s)
    raise PermanentError, "Rebuild webhook URL must be https" unless uri.is_a?(URI::HTTPS)
    raise PermanentError, "Rebuild webhook URL must not include credentials" if uri.user.present? || uri.password.present?
    raise PermanentError, "Rebuild webhook URL has no host" if uri.host.blank?
    raise PermanentError, "Rebuild webhook secret is missing" if @website.rebuild_webhook_secret.blank?

    uri
  rescue URI::InvalidURIError
    raise PermanentError, "Rebuild webhook URL is invalid"
  end

  def assert_public_host!(uri)
    addresses = self.class.address_lookup.call(uri.host)
    raise DeliveryError, "Rebuild webhook host did not resolve" if addresses.empty?

    addresses.each do |address|
      raise PermanentError, "Rebuild webhook host is not public" if blocked_ip?(IPAddr.new(address))
    end
  rescue Resolv::ResolvError => error
    raise DeliveryError, error.message
  rescue IPAddr::InvalidAddressError
    raise PermanentError, "Rebuild webhook host is not public"
  end

  def blocked_ip?(ip)
    ip = ip.native
    return true if ip.private? || ip.loopback? || ip.link_local?
    return true if ip.ipv4? && blocked_ipv4?(ip)
    return true if ip.ipv6? && IPAddr.new("2001:db8::/32").include?(ip)

    false
  end

  def blocked_ipv4?(ip)
    [
      "0.0.0.0/8",
      "100.64.0.0/10",
      "192.0.0.0/24",
      "192.0.2.0/24",
      "198.18.0.0/15",
      "198.51.100.0/24",
      "203.0.113.0/24",
      "224.0.0.0/4",
      "240.0.0.0/4"
    ].any? { |cidr| IPAddr.new(cidr).include?(ip) }
  end

  def request_body(uri)
    event = {
      event: "content.changed",
      content_type: @content_type,
      website: { domain: @website.domain },
      updated_at: @website.content_updated_at(@content_type)
    }
    payload = if github_dispatch?(uri)
      { event_type: EVENT_TYPE, client_payload: event }
    else
      event
    end
    JSON.generate(payload)
  end

  def github_dispatch?(uri)
    uri.host == "api.github.com" && GITHUB_DISPATCH_PATH.match?(uri.path)
  end

  def signature_for(body, timestamp)
    OpenSSL::HMAC.hexdigest("SHA256", @website.rebuild_webhook_secret, "#{timestamp}.#{body}")
  end

  def interpret!(response)
    return if response.is_a?(Net::HTTPSuccess)

    code = response.code.to_i
    raise DeliveryError, "Rebuild webhook returned #{code}" if code >= 500 || code == 429

    raise PermanentError, "Rebuild webhook returned #{code}"
  end
end

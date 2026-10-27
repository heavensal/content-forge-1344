# frozen_string_literal: true

require "ipaddr"
require "net/http"
require "resolv"
require "stringio"
require "tempfile"

module Mcp
  class ArticleImages
    class Error < ArgumentError; end

    Response = Data.define(:code, :body, :content_type, :location)
    OWNED_URL = %r{\Ahttps://res\.cloudinary\.com/[a-z0-9_-]+/image/upload/(?:v\d+/)?(forge/[a-z0-9]+(?:-[a-z0-9]+)*/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})(?:\.\w+)?(?:\?\S*)?\z}i

    class << self
      attr_writer :address_lookup, :http_get

      def import!(website, attributes)
        new(website).import(attributes)
      end

      def https_url?(value)
        uri = URI.parse(value.to_s)
        uri.is_a?(URI::HTTPS) && uri.host.present? && uri.user.nil? && uri.password.nil? && value.to_s.bytesize <= 2_000
      rescue URI::InvalidURIError
        false
      end

      def download(url)
        body, content_type = fetch(URI.parse(url), 0)
        type = Marcel::MimeType.for(StringIO.new(body), declared_type: content_type.to_s.split(";").first.to_s)
        type = "image/jpeg" if type == "image/jpg"
        raise Error, I18n.t("article.images.invalid_type") unless CloudinaryImages::ALLOWED_TYPES.include?(type)

        file = Tempfile.new([ "forge-image", ".#{extension(type)}" ])
        file.binmode
        file.write(body)
        file.rewind
        downloaded_image(file, type)
      end

      def address_lookup
        @address_lookup ||= ->(host) { Resolv.getaddresses(host) }
      end

      def http_get
        @http_get ||= ->(uri) { default_http_get(uri) }
      end

      private

      def fetch(uri, hops)
        assert_public!(uri)
        response = http_get.call(uri)
        if response.code.between?(300, 399)
          raise Error, "Image URL redirected too many times" if hops >= 3
          raise Error, "Image download failed" if response.location.blank?

          return fetch(URI.join(uri, response.location), hops + 1)
        end
        raise Error, "Image download failed" unless response.code == 200

        [ response.body, response.content_type ]
      end

      def assert_public!(uri)
        raise Error, "Image URL must be https" unless uri.is_a?(URI::HTTPS) && uri.host.present? && uri.user.nil? && uri.password.nil?

        addresses = address_lookup.call(uri.host)
        raise Error, "Image URL is not public" if addresses.blank?

        addresses.each do |address|
          raise Error, "Image URL is not public" if blocked_ip?(IPAddr.new(address))
        end
      rescue Resolv::ResolvError, IPAddr::InvalidAddressError
        raise Error, "Image URL is not public"
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

      def default_http_get(uri)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        http.open_timeout = 5
        http.read_timeout = 20
        http.max_retries = 0
        request = Net::HTTP::Get.new(uri)
        request["User-Agent"] = "Forge/1"
        request["Accept"] = "image/*"
        http.start do
          http.request(request) do |response|
            if response.is_a?(Net::HTTPRedirection)
              return Response.new(code: response.code.to_i, body: +"", content_type: nil, location: response["location"])
            end
            unless response.is_a?(Net::HTTPSuccess)
              return Response.new(code: response.code.to_i, body: +"", content_type: response["content-type"], location: nil)
            end

            body = +"".b
            response.read_body do |chunk|
              body << chunk
              raise Error, I18n.t("article.images.too_large") if body.bytesize > CloudinaryImages::MAX_BYTES
            end
            return Response.new(code: response.code.to_i, body: body, content_type: response["content-type"], location: nil)
          end
        end
      end

      def extension(type)
        { "image/jpeg" => "jpg", "image/png" => "png", "image/webp" => "webp", "image/gif" => "gif" }.fetch(type)
      end

      def downloaded_image(file, type)
        Struct.new(:tempfile, :path, :content_type, :original_filename) do
          def size
            tempfile.size
          end

          def read(...)
            tempfile.read(...)
          end

          def close!
            tempfile.close!
          end
        end.new(file, file.path, type, "image.#{extension(type)}")
      end
    end

    def initialize(website)
      @website = website
      @copies = {}
    end

    def import(attributes)
      result = attributes.dup
      if result.key?("cover_image_url")
        if result["cover_image_url"].blank?
          result["cover_image_url"] = nil
          result["cover_image_public_id"] = nil
        else
          uploaded = copy(result["cover_image_url"])
          result["cover_image_url"] = uploaded.url
          result["cover_image_public_id"] = uploaded.public_id
        end
      end
      result["content"] = rewrite(result["content"]) if result["content"].present?
      result
    end

    private

    def rewrite(html)
      fragment = Nokogiri::HTML5.fragment(html)
      images = fragment.css("img")
      return html if images.empty?

      images.each do |image|
        uploaded = copy(image["src"])
        image["src"] = uploaded.url
        image["width"] = uploaded.width.to_s if uploaded.width
        image["height"] = uploaded.height.to_s if uploaded.height
      end
      fragment.to_html
    end

    def copy(url)
      @copies[url] ||= begin
        if (public_id = owned_public_id(url))
          CloudinaryImages::Result.new(public_id: public_id, url: url, width: nil, height: nil)
        else
          io = self.class.download(url)
          begin
            CloudinaryImages.upload!(website: @website, io: io)
          ensure
            io.close! if io.respond_to?(:close!)
          end
        end
      end
    rescue CloudinaryImages::Error => error
      raise Error, error.message
    end

    def owned_public_id(url)
      public_id = url.to_s.match(OWNED_URL)&.[](1)
      return if public_id.blank?
      return unless public_id.start_with?("forge/#{@website.cloudinary_folder}/")
      return unless public_id.match?(CloudinaryImages::PUBLIC_ID_PATTERN)

      public_id
    end
  end
end

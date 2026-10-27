module Mcp
  module Content
    FIELDS = {
      "articles" => %w[title slug description content locale cover_image_url],
      "reviews" => %w[author content rating position locale],
      "faqs" => %w[question slug answer position locale]
    }.freeze

    def self.websites(user)
      (user.admin? ? Website.all : user.websites).active
    end

    def self.scope(website, type)
      raise ArgumentError, "Unknown content type" unless FIELDS.key?(type)
      website.public_send(type)
    end

    def self.serialize(record, type)
      fields = FIELDS.fetch(type) + %w[id website_id status published_at updated_at]
      fields.to_h do |field|
        value = field == "content" && type == "articles" ? record.public_content_html.to_s : record.public_send(field)
        [ field, value ]
      end.as_json
    end

    def self.digest(record, type)
      Digest::SHA256.hexdigest(JSON.generate(serialize(record, type)))
    end

    def self.attributes(type, payload)
      raise ArgumentError, "Attributes must be an object" unless payload.is_a?(Hash)
      raise ArgumentError, "Unknown attributes" if (payload.keys - FIELDS.fetch(type)).any?
      payload.each do |key, value|
        if %w[rating position].include?(key)
          raise ArgumentError, "#{key} must be an integer" unless value.is_a?(Integer) && value.between?(0, 1_000_000)
        else
          raise ArgumentError, "#{key} must be a string (maximum 100000 bytes)" unless value.is_a?(String) && value.bytesize <= 100_000
        end
      end
      # Do not allow Action Text attachment signed IDs to reference another client's files.
      if type == "articles"
        payload = payload.merge("cover_image_url" => cover_image_url(payload["cover_image_url"])) if payload.key?("cover_image_url")
        payload = payload.merge("content" => article_html(payload["content"])) if payload.key?("content")
      end
      payload
    end

    def self.cover_image_url(value)
      return "" if value.blank?
      raise ArgumentError, "cover_image_url must be an https URL" unless ArticleImages.https_url?(value)

      value
    end

    def self.article_html(html)
      original = Nokogiri::HTML5.fragment(html.to_s)
      images = original.css("img")
      raise ArgumentError, "An article can contain at most 12 images" if images.size > 12
      images.each do |image|
        raise ArgumentError, "Article images must use https URLs" unless ArticleImages.https_url?(image["src"].to_s)
      end
      Rails::HTML5::SafeListSanitizer.new.sanitize(
        html.to_s,
        tags: %w[p br strong em ul ol li h2 h3 blockquote a figure figcaption img],
        attributes: %w[href title src alt width height]
      )
    end
  end
end

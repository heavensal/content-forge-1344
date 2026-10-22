module Mcp
  module Content
    FIELDS = {
      "articles" => %w[title slug description content locale],
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
        value = field == "content" && type == "articles" ? record.content.body&.to_html.to_s : record.public_send(field)
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
      if type == "articles" && payload.key?("content")
        payload = payload.merge("content" => Rails::HTML5::SafeListSanitizer.new.sanitize(payload["content"], tags: %w[p br strong em ul ol li h2 h3 blockquote a], attributes: %w[href title]))
      end
      payload
    end
  end
end

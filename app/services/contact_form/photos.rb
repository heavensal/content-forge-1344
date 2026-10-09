# frozen_string_literal: true

module ContactForm
  class Photos
    MAX_COUNT = 3
    MAX_BYTES = 1_200_000
    JPEG_MAGIC = "\xFF\xD8\xFF".b

    class Rejected < StandardError; end

    def self.prepare(raw)
      items = list_from(raw)
      raise Rejected, "Send at most 3 photos." if items.size > MAX_COUNT

      items.map.with_index(1) { |item, index| prepare_one(item, index) }
    end

    def self.list_from(raw)
      return [] if raw.blank?
      return raw.to_a if raw.is_a?(Array)

      []
    end

    def self.prepare_one(item, index)
      encoded = item_value(item, "data").to_s.sub(/\Adata:image\/[a-z0-9.+-]+;base64,/i, "")
      raise Rejected, "A photo could not be read. Use a JPEG." if encoded.blank? || encoded.bytesize > (MAX_BYTES * 4 / 3) + 16

      binary = Base64.strict_decode64(encoded)
      raise Rejected, "A photo is too large." if binary.bytesize > MAX_BYTES
      raise Rejected, "A photo could not be read. Use a JPEG." unless binary.b.start_with?(JPEG_MAGIC)

      { filename: "photo-#{index}.jpg", content_type: "image/jpeg", data: binary }
    rescue ArgumentError
      raise Rejected, "A photo could not be read. Use a JPEG."
    end

    def self.item_value(item, key)
      return item[key] if item.respond_to?(:[])

      nil
    end
    private_class_method :list_from, :prepare_one, :item_value
  end
end

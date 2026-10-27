# frozen_string_literal: true

class CloudinaryImages
  class Error < StandardError; end

  ROOT = "forge"
  MAX_BYTES = 8.megabytes
  ALLOWED_TYPES = %w[image/jpeg image/png image/webp image/gif].freeze
  PUBLIC_ID_PATTERN = %r{\Aforge/[a-z0-9]+(?:-[a-z0-9]+)*/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z}

  Result = Data.define(:public_id, :url, :width, :height)

  def self.upload!(website:, io:)
    new(website).upload!(io)
  end

  def self.configured?
    Cloudinary.config.cloud_name.present? &&
      Cloudinary.config.api_key.present? &&
      Cloudinary.config.api_secret.present?
  end

  def self.destroy(public_id)
    return if public_id.blank?
    return unless public_id.match?(PUBLIC_ID_PATTERN)
    return unless configured?

    Cloudinary::Uploader.destroy(public_id, resource_type: "image", invalidate: true)
  rescue CloudinaryException => error
    Rails.logger.warn("Cloudinary destroy failed for #{public_id}: #{error.message}")
  end

  def initialize(website)
    @website = website
  end

  def upload!(io)
    raise Error, I18n.t("article.images.blank") if io.blank? || !io.respond_to?(:read)
    raise Error, configuration_message unless self.class.configured?

    content_type = detected_type(io)
    raise Error, I18n.t("article.images.invalid_type") unless ALLOWED_TYPES.include?(content_type)
    raise Error, I18n.t("article.images.too_large") if byte_size(io) > MAX_BYTES

    public_id = build_public_id
    response = upload_file(upload_source(io), upload_options(public_id))
    Result.new(
      public_id: response.fetch("public_id"),
      url: response.fetch("secure_url"),
      width: response["width"],
      height: response["height"]
    )
  rescue CloudinaryException => error
    Rails.logger.error("Cloudinary upload failed: #{error.message}")
    raise Error, I18n.t("article.images.failed")
  end

  private

  def configuration_message
    I18n.t("article.images.unconfigured")
  end

  def build_public_id
    "#{ROOT}/#{@website.cloudinary_folder}/#{SecureRandom.uuid}"
  end

  def upload_options(public_id)
    folder, unique_id = public_id.rpartition("/").values_at(0, 2)
    {
      public_id: public_id,
      asset_folder: folder,
      display_name: unique_id,
      resource_type: "image",
      overwrite: false,
      unique_filename: false,
      use_filename: false,
      use_asset_folder_as_public_id_prefix: false,
      discard_original_filename: true
    }
  end

  def upload_file(source, options)
    Cloudinary::Uploader.upload(source, options)
  rescue CloudinaryException => error
    raise unless dynamic_folder_rejected?(error)

    rewind(source)
    Cloudinary::Uploader.upload(source, options.except(:asset_folder, :display_name, :use_asset_folder_as_public_id_prefix))
  end

  def dynamic_folder_rejected?(error)
    error.message.match?(/asset_folder|display_name|dynamic folder/i)
  end

  def upload_source(io)
    path = io.path if io.respond_to?(:path)
    path.present? ? path : io
  end

  def detected_type(io)
    source = upload_source(io)
    type = if source.is_a?(String)
      File.open(source, "rb") { |file| marcel_type(file, io) }
    else
      rewind(source)
      marcel_type(source, io).tap { rewind(source) }
    end
    type == "image/jpg" ? "image/jpeg" : type
  end

  def marcel_type(source, io)
    Marcel::MimeType.for(
      source,
      name: io.try(:original_filename),
      declared_type: io.try(:content_type)
    )
  end

  def byte_size(io)
    path = io.path if io.respond_to?(:path)
    return File.size(path) if path.present?

    io.size
  end

  def rewind(source)
    source.rewind if source.respond_to?(:rewind)
  end
end

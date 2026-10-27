# frozen_string_literal: true

class Article < ApplicationRecord
  belongs_to :website
  include ContentLocale
  include RebuildsWebsite
  rebuilds_website_as "articles"
  has_rich_text :content

  enum :status, { draft: "draft", published: "published", archived: "archived" }, validate: true

  normalizes :slug, with: ->(s) { s.to_s.parameterize.presence }

  validates :title, presence: true
  validates :slug, presence: true, uniqueness: { scope: %i[website_id locale] }
  validate :published_at_present_when_published

  before_validation :assign_slug, on: :create
  before_save :assign_cover_image
  after_commit :release_replaced_cover_image, on: %i[create update]
  after_destroy_commit :release_destroyed_cover_image

  attr_accessor :cover_image, :remove_cover_image

  scope :for_public_api, lambda {
    published.where(published_at: ..Time.current)
  }

  def public_content_html
    html = content&.body&.to_html.to_s
    return if html.blank?
    return html unless html.include?("action-text-attachment")

    fragment = Nokogiri::HTML5.fragment(html)
    fragment.css("action-text-attachment").each do |node|
      url = node["url"].to_s
      content_type = node["content-type"].to_s
      # Trix stores a bare "image" type when the browser does not know the MIME type.
      image_attachment = content_type == "image" || content_type.start_with?("image/")
      unless image_attachment && url.match?(%r{\Ahttps://}i)
        node.remove if image_attachment
        next
      end

      figure = Nokogiri::XML::Node.new("figure", fragment.document)
      image = Nokogiri::XML::Node.new("img", fragment.document)
      image["src"] = url
      image["alt"] = node["caption"].to_s
      image["width"] = node["width"] if node["width"].to_s.match?(/\A\d+\z/)
      image["height"] = node["height"] if node["height"].to_s.match?(/\A\d+\z/)
      figure.add_child(image)
      if node["caption"].present?
        caption = Nokogiri::XML::Node.new("figcaption", fragment.document)
        caption.content = node["caption"]
        figure.add_child(caption)
      end
      node.replace(figure)
    end
    fragment.to_html
  end

  def self.release_cover_image(public_id)
    return if public_id.blank?
    return if exists?(cover_image_public_id: public_id)

    CloudinaryImages.destroy(public_id)
  end

  private

  def published_at_present_when_published
    return unless published?
    return if published_at.present?

    errors.add(:published_at, :blank)
  end

  def assign_slug
    return if slug.present?

    base = title.to_s.parameterize
    base = "article" if base.blank?

    candidate = base
    suffix = 2
    while Article.where(website_id: website_id, locale: locale).exists?(slug: candidate)
      candidate = "#{base}-#{suffix}"
      suffix += 1
    end
    self.slug = candidate
  end

  def assign_cover_image
    # Attribute assignment (the MCP apply path) changes the id before this runs.
    # Release that previous id only after commit, same as a file upload.
    previous_public_id = cover_image_public_id_was
    if cover_image.present?
      uploaded = CloudinaryImages.upload!(website: website, io: cover_image)
      self.cover_image_public_id = uploaded.public_id
      self.cover_image_url = uploaded.url
    elsif ActiveModel::Type::Boolean.new.cast(remove_cover_image)
      self.cover_image_public_id = nil
      self.cover_image_url = nil
    end

    return if previous_public_id.blank? || previous_public_id == cover_image_public_id

    @cover_public_id_to_release = previous_public_id
  rescue CloudinaryImages::Error => error
    errors.add(:base, error.message)
    throw :abort
  ensure
    self.cover_image = nil
    self.remove_cover_image = nil
  end

  def release_replaced_cover_image
    public_id = @cover_public_id_to_release
    @cover_public_id_to_release = nil
    self.class.release_cover_image(public_id)
  end

  def release_destroyed_cover_image
    self.class.release_cover_image(cover_image_public_id)
  end
end

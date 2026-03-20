# frozen_string_literal: true

class Article < ApplicationRecord
  belongs_to :website
  has_rich_text :content

  enum :status, { draft: "draft", published: "published", archived: "archived" }, validate: true

  normalizes :slug, with: ->(s) { s.to_s.parameterize.presence }

  validates :title, presence: true
  validates :slug, presence: true, uniqueness: { scope: :website_id }
  validate :published_at_present_when_published

  before_validation :assign_slug, on: :create

  scope :for_public_api, lambda {
    published.where(published_at: ..Time.current)
  }

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
    while Article.where(website_id: website_id).exists?(slug: candidate)
      candidate = "#{base}-#{suffix}"
      suffix += 1
    end
    self.slug = candidate
  end
end

# frozen_string_literal: true

class Faq < ApplicationRecord
  belongs_to :website

  enum :status, { draft: "draft", published: "published", archived: "archived" }, validate: true

  normalizes :slug, with: ->(s) { s.to_s.parameterize.presence }

  validates :question, presence: true
  validates :slug, presence: true, uniqueness: { scope: :website_id }
  validates :answer, presence: true, if: :published?
  validate :published_at_present_when_published

  before_validation :assign_slug, on: :create

  scope :for_public_api, lambda {
    published.where(published_at: ..Time.current)
  }

  scope :ordered, -> { order(:position, :id) }

  private

  def published_at_present_when_published
    return unless published?
    return if published_at.present?

    errors.add(:published_at, :blank)
  end

  def assign_slug
    return if slug.present?

    base = question.to_s.parameterize
    base = "faq" if base.blank?

    candidate = base
    suffix = 2
    while Faq.where(website_id: website_id).exists?(slug: candidate)
      candidate = "#{base}-#{suffix}"
      suffix += 1
    end
    self.slug = candidate
  end
end

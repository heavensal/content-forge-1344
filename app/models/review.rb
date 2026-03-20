# frozen_string_literal: true

class Review < ApplicationRecord
  belongs_to :website

  enum :status, { draft: "draft", published: "published", archived: "archived" }, validate: true

  validates :author, presence: true, if: :published?
  validates :content, presence: true, if: :published?
  validate :published_at_present_when_published

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
end

# frozen_string_literal: true

class Website < ApplicationRecord
  has_many :website_memberships, dependent: :destroy
  has_many :users, through: :website_memberships
  has_many :articles, dependent: :destroy
  has_many :faqs, dependent: :destroy
  has_many :reviews, dependent: :destroy

  has_secure_token :api_token
  has_secure_token :rebuild_webhook_secret

  enum :status, { active: "active", archived: "archived" }, validate: true
  enum :default_locale, ContentLocale::LOCALES.index_with(&:itself), validate: true, prefix: :default_locale

  normalizes :domain, with: ->(d) { d.to_s.strip.downcase }
  normalizes :email, with: ->(e) { e.to_s.strip.presence }
  normalizes :rebuild_webhook_url, with: ->(url) { url.to_s.strip.sub(%r{/+\z}, "").presence }
  normalizes :rebuild_webhook_token, with: ->(token) { token.to_s.strip.presence }

  validates :name, presence: true
  validates :domain, presence: true, uniqueness: { case_sensitive: false }
  validates :email, format: { with: Devise.email_regexp }, allow_blank: true
  validates :rebuild_webhook_url, length: { maximum: 2048 }, allow_blank: true
  validate :rebuild_webhook_url_must_be_https

  before_validation :ensure_api_token, on: :create

  def schedule_rebuild!(content_type)
    content_type = content_type.to_s
    return unless rebuild_for?(content_type)

    DeliverWebsiteRebuildJob.perform_later(id, content_type)
  end

  def rebuild_for?(content_type)
    return false unless active?
    return false if rebuild_webhook_url.blank?

    case content_type.to_s
    when "articles" then imports_articles?
    when "faqs" then imports_faqs?
    when "reviews" then imports_reviews?
    else false
    end
  end

  def content_updated_at(content_type)
    scope = case content_type.to_s
    when "articles" then articles
    when "faqs" then faqs
    when "reviews" then reviews
    else return nil
    end
    scope.for_public_api.maximum(:updated_at)&.iso8601
  end

  private

  def ensure_api_token
    regenerate_api_token if api_token.blank?
  end

  def rebuild_webhook_url_must_be_https
    return if rebuild_webhook_url.blank?

    uri = URI.parse(rebuild_webhook_url)
    return if uri.is_a?(URI::HTTPS) && uri.host.present?

    errors.add(:rebuild_webhook_url, "must be an https URL")
  rescue URI::InvalidURIError
    errors.add(:rebuild_webhook_url, "must be an https URL")
  end
end

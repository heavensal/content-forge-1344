# frozen_string_literal: true

module ContentLocale
  extend ActiveSupport::Concern

  LOCALES = %w[fr en].freeze

  included do
    enum :locale, LOCALES.index_with(&:itself), validate: true

    before_validation :assign_default_content_locale, prepend: true
  end

  private

  def assign_default_content_locale
    return unless new_record?
    return if locale_changed? && locale.present?

    self.locale = website&.default_locale.presence || "fr"
  end
end

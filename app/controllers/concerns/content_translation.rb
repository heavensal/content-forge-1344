# frozen_string_literal: true

module ContentTranslation
  extend ActiveSupport::Concern

  private

  def chosen_content_locale
    params[:locale].to_s.presence_in(ContentLocale::LOCALES) || @website.default_locale
  end

  def translation_source(relation)
    return if params[:from].blank?

    relation.find(params[:from])
  end
end

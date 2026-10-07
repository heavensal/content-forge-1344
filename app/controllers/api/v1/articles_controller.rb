# frozen_string_literal: true

module Api
  module V1
    class ArticlesController < BaseController
      def index
        articles = localized(@website.articles.for_public_api).order(published_at: :desc)
        render_public_collection(articles) { |article| article_json(article) }
      end

      def show
        render json: article_json(find_public_article)
      end

      private

      def find_public_article
        scope = @website.articles.for_public_api
        locale = requested_locale
        article = scope.find_by(slug: params[:slug], locale: locale)
        return article if article
        if locale != @website.default_locale
          fallback = scope.find_by(slug: params[:slug], locale: @website.default_locale)
          return fallback if fallback
        end

        raise ActiveRecord::RecordNotFound
      end

      def article_json(article)
        {
          id: article.id,
          title: article.title,
          slug: article.slug,
          locale: article.locale,
          description: article.description,
          published_at: article.published_at&.iso8601,
          updated_at: article.updated_at.iso8601,
          content_html: article.content.present? ? article.content.body.to_html : nil
        }
      end
    end
  end
end

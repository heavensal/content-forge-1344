# frozen_string_literal: true

module Api
  module V1
    class ArticlesController < BaseController
      def index
        articles = @website.articles.for_public_api.order(published_at: :desc)
        render json: articles.map { |a| article_json(a) }
      end

      private

      def article_json(article)
        {
          id: article.id,
          title: article.title,
          slug: article.slug,
          description: article.description,
          published_at: article.published_at&.iso8601,
          content_html: article.content.present? ? article.content.body.to_html : nil
        }
      end
    end
  end
end

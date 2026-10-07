# frozen_string_literal: true

module Api
  module V1
    class ReviewsController < BaseController
      def index
        reviews = localized(@website.reviews.for_public_api).ordered
        render_public_collection(reviews) { |review| review_json(review) }
      end

      private

      def review_json(review)
        {
          id: review.id,
          author: review.author,
          content: review.content,
          rating: review.rating,
          position: review.position,
          locale: review.locale,
          published_at: review.published_at&.iso8601,
          updated_at: review.updated_at.iso8601
        }
      end
    end
  end
end

# frozen_string_literal: true

module Api
  module V1
    class ReviewsController < BaseController
      def index
        reviews = @website.reviews.for_public_api.ordered
        render json: reviews.map { |r| review_json(r) }
      end

      private

      def review_json(review)
        {
          id: review.id,
          author: review.author,
          content: review.content,
          position: review.position,
          published_at: review.published_at&.iso8601
        }
      end
    end
  end
end

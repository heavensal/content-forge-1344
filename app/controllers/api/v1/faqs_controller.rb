# frozen_string_literal: true

module Api
  module V1
    class FaqsController < BaseController
      def index
        faqs = @website.faqs.for_public_api.ordered
        render json: faqs.map { |f| faq_json(f) }
      end

      private

      def faq_json(faq)
        {
          id: faq.id,
          question: faq.question,
          slug: faq.slug,
          answer: faq.answer,
          position: faq.position,
          published_at: faq.published_at&.iso8601
        }
      end
    end
  end
end

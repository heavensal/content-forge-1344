# frozen_string_literal: true

module Api
  module V1
    class FaqsController < BaseController
      def index
        faqs = localized(@website.faqs.for_public_api).ordered
        render_public_collection(faqs) { |faq| faq_json(faq) }
      end

      private

      def faq_json(faq)
        {
          id: faq.id,
          question: faq.question,
          slug: faq.slug,
          answer: faq.answer,
          position: faq.position,
          locale: faq.locale,
          published_at: faq.published_at&.iso8601,
          updated_at: faq.updated_at.iso8601
        }
      end
    end
  end
end

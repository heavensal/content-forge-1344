# frozen_string_literal: true

module Api
  module V1
    class BaseController < ActionController::API
      before_action :authenticate_website_from_bearer!

      rescue_from ActiveRecord::RecordNotFound do
        render json: { error: "Not found" }, status: :not_found
      end

      private

      def authenticate_website_from_bearer!
        token = bearer_token
        @website = Website.active.find_by(api_token: token) if token.present?

        return if @website

        render json: { error: "Unauthorized" }, status: :unauthorized
      end

      def bearer_token
        request.authorization.to_s.remove(/\ABearer\s+/i).presence
      end

      def requested_locale
        value = params[:locale].to_s
        return value if ContentLocale::LOCALES.include?(value)

        @website.default_locale
      end

      def localized(relation)
        locale = requested_locale
        scoped = relation.where(locale: locale)
        return scoped if scoped.exists? || locale == @website.default_locale

        relation.where(locale: @website.default_locale)
      end

      def render_public_collection(records)
        list = records.to_a
        updated_at = list.filter_map(&:updated_at).max&.iso8601
        response.set_header("X-Content-Updated-At", updated_at) if updated_at
        render json: {
          updated_at: updated_at,
          data: list.map { |record| yield(record) }
        }
      end
    end
  end
end

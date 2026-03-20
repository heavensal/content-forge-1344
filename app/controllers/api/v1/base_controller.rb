# frozen_string_literal: true

module Api
  module V1
    class BaseController < ActionController::API
      before_action :authenticate_website_from_bearer!

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
    end
  end
end

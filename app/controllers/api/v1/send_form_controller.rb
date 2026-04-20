# frozen_string_literal: true

module Api
  module V1
    class SendFormController < BaseController
      def create
        unless @website.email.present?
          return render json: {
            error: "This website has no contact email. Set it on the website in ContentForge."
          }, status: :unprocessable_entity
        end

        payload = normalized_payload
        unless main_content_present?(payload)
          return render json: {
            error: "Provide at least one of: message, body, or non-empty fields."
          }, status: :unprocessable_entity
        end

        if payload[:from_email].present? && !payload[:from_email].match?(Devise.email_regexp)
          return render json: { error: "from_email is not a valid email address" }, status: :unprocessable_entity
        end

        mail = SiteContactMailer.forward_inquiry(
          website: @website,
          from_email: payload[:from_email],
          from_name: payload[:from_name],
          subject: payload[:subject],
          message: payload[:message],
          fields: payload[:fields]
        )
        begin
          mail.deliver_now
        rescue StandardError => e
          Rails.logger.error("[SendForm] #{e.class}: #{e.message}")
          return render json: { error: "Mail could not be sent. Try again later." }, status: :bad_gateway
        end

        render json: { ok: true }, status: :created
      end

      private

      def normalized_payload
        p = params.permit(:from_email, :from_name, :subject, :message, :body, fields: {})
        msg = p[:message].presence || p[:body].presence
        fields = extract_fields_hash(p[:fields])

        {
          from_email: p[:from_email].to_s.strip.presence,
          from_name: p[:from_name].to_s.strip.presence,
          subject: p[:subject].to_s.strip.presence,
          message: msg.to_s.strip.presence,
          fields: fields.transform_values { |v| v.is_a?(Array) ? v.join(", ") : v }
        }
      end

      def main_content_present?(payload)
        payload[:message].present? || payload[:fields].values.any?(&:present?)
      end

      def extract_fields_hash(raw)
        case raw
        when ActionController::Parameters
          raw.permitted? ? raw.to_h : {}
        when Hash
          raw.stringify_keys
        else
          {}
        end
      end
    end
  end
end

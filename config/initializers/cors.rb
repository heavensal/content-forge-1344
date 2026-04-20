# frozen_string_literal: true

# Browser requests from external brochure sites (e.g. arm-services.fr) to the JSON API
# require CORS. Restrict origins in production via CORS_ALLOWED_ORIGINS (comma-separated).
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    raw = ENV.fetch("CORS_ALLOWED_ORIGINS", "*").split(",").map(&:strip).reject(&:empty?)
    origins(*raw.presence || [ "*" ])

    resource "/api/*",
      headers: :any,
      methods: %i[get post put patch delete options head],
      max_age: 600
  end
end

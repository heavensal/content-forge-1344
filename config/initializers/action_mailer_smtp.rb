# frozen_string_literal: true

# SMTP (mail.1344.fr, port 465 SSL) — enabled when SMTP_ADDRESS is set (see .env.example).
if ENV["SMTP_ADDRESS"].present?
  Rails.application.config.action_mailer.delivery_method = :smtp
  Rails.application.config.action_mailer.smtp_settings = {
    address: ENV.fetch("SMTP_ADDRESS"),
    port: Integer(ENV.fetch("SMTP_PORT", 465)),
    user_name: ENV.fetch("SMTP_USER_NAME"),
    password: ENV.fetch("SMTP_PASSWORD"),
    authentication: :plain,
    enable_starttls_auto: false,
    ssl: true
  }
  Rails.application.config.action_mailer.default_options = {
    from: ENV.fetch("MAILER_FROM", "noreply@1344.fr")
  }
end

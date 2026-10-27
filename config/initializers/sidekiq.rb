# frozen_string_literal: true

# Sidekiq connects on the first command, not at boot, so asset precompile
# does not need a live Redis. Production sets REDIS_URL in config/deploy.yml.
redis_url = ENV.fetch("REDIS_URL", "redis://127.0.0.1:6379/0")

Sidekiq.configure_server do |config|
  config.redis = { url: redis_url }
end

Sidekiq.configure_client do |config|
  config.redis = { url: redis_url }
end

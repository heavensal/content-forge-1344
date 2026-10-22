module Mcp
  module Settings
    SCOPES = %w[content:read content:write content:publish].freeze

    def self.https_url(name)
      value = ENV.fetch(name)
      uri = URI.parse(value)
      raise ArgumentError, "Invalid #{name}" unless uri.is_a?(URI::HTTPS) && uri.host.present? && !uri.userinfo && !uri.fragment && !uri.query
      value
    end

    def self.resource
      https_url("MCP_RESOURCE_URL")
    end

    def self.issuer
      base_url
    end

    def self.base_url
      uri = URI.parse(resource)
      "#{uri.scheme}://#{uri.host}#{uri.port == 443 ? '' : ":#{uri.port}"}"
    end

    def self.metadata_url
      "#{base_url}/.well-known/oauth-protected-resource"
    end
  end
end

require "net/http"

module Mcp
  class Authentication
    class Unauthorized < StandardError; end
    class Unavailable < StandardError; end
    Context = Data.define(:user, :scopes)
    CLOCK_SKEW = IdentityProvider::CLOCK_SKEW

    def self.call(header)
      token = header.to_s.match(/\ABearer ([A-Za-z0-9\-._~+\/=]+)\z/i)&.captures&.first
      raise Unauthorized unless token && token.bytesize <= 8192
      claims = introspect(token)
      now = Time.current.to_i
      valid = claims.is_a?(Hash) && claims["active"] == true &&
        claims["iss"] == Settings.issuer && Array(claims["aud"]).include?(Settings.resource) &&
        claims["exp"].is_a?(Numeric) && claims["exp"] > now &&
        (!claims.key?("nbf") || (claims["nbf"].is_a?(Numeric) && claims["nbf"] <= now + CLOCK_SKEW)) &&
        claims["sub"].is_a?(String) && claims["sub"].present? && claims["scope"].is_a?(String)
      raise Unauthorized unless valid
      identity = McpIdentity.find_by(issuer: Settings.issuer, subject: claims["sub"], revoked_at: nil)
      raise Unauthorized unless identity
      Context.new(user: identity.user, scopes: claims["scope"].split.freeze)
    end

    def self.introspect(token)
      uri = URI.parse(Settings.https_url("MCP_OAUTH_INTROSPECTION_URL"))
      request = Net::HTTP::Post.new(uri)
      request.basic_auth(ENV.fetch("MCP_OAUTH_CLIENT_ID"), ENV.fetch("MCP_OAUTH_CLIENT_SECRET"))
      request.set_form_data(token: token, token_type_hint: "access_token")
      body = +""
      Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 3, read_timeout: 5, max_retries: 0) do |http|
        http.request(request) do |response|
          raise Unavailable unless response.is_a?(Net::HTTPSuccess)
          response.read_body do |chunk|
            body << chunk
            raise Unavailable if body.bytesize > 65_536
          end
        end
      end
      JSON.parse(body)
    rescue JSON::ParserError, IOError, SystemCallError, Timeout::Error, OpenSSL::SSL::SSLError, SocketError
      raise Unavailable
    end
  end
end

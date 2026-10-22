require "net/http"
require "openssl"
require "base64"

module Mcp
  class IdentityProvider
    class Failure < StandardError; end
    IDENTITY_SESSION_KEY = :mcp_identity_link
    DISCOVERY_TTL = 10.minutes
    CLOCK_SKEW = 60

    class << self
      def authorization_url(state:, nonce:, challenge:)
        metadata = discovery
        uri = safe_https_uri(metadata.fetch("authorization_endpoint"))
        uri.query = URI.encode_www_form(
          response_type: "code", client_id: client_id, redirect_uri: redirect_uri,
          scope: "openid profile email", state: state, nonce: nonce,
          code_challenge: challenge, code_challenge_method: "S256"
        )
        uri.to_s
      end

      def exchange_and_identify!(code:, verifier:, nonce:)
        metadata = discovery
        endpoint = safe_https_uri(metadata.fetch("token_endpoint"))
        request = Net::HTTP::Post.new(endpoint)
        request.basic_auth(client_id, client_secret)
        request.set_form_data(grant_type: "authorization_code", code: code,
          redirect_uri: redirect_uri, code_verifier: verifier)
        tokens = JSON.parse(http_request(endpoint, request, limit: 65_536))
        verify_id_token!(tokens.fetch("id_token"), nonce: nonce, metadata: metadata)
      rescue KeyError, JSON::ParserError, URI::InvalidURIError, OpenSSL::PKey::PKeyError, OpenSSL::OpenSSLError, ArgumentError, TypeError
        raise Failure, "The identity provider returned an invalid response"
      end

      def issuer
        Settings.issuer
      end

      private

      def client_id
        ENV.fetch("MCP_LINK_CLIENT_ID")
      end

      def client_secret
        ENV.fetch("MCP_LINK_CLIENT_SECRET")
      end

      def redirect_uri
        Settings.https_url("MCP_LINK_REDIRECT_URI")
      end

      def discovery
        Rails.cache.fetch("mcp/oidc-discovery/#{issuer}", expires_in: DISCOVERY_TTL) do
          url = "#{issuer.sub(%r{/+\z}, '')}/.well-known/openid-configuration"
          metadata = JSON.parse(http_request(safe_https_uri(url), Net::HTTP::Get.new(url), limit: 65_536))
          raise Failure unless metadata["issuer"] == issuer
          %w[authorization_endpoint token_endpoint jwks_uri].each { |field| safe_https_uri(metadata.fetch(field)) }
          metadata
        end
      rescue KeyError, JSON::ParserError, URI::InvalidURIError, ArgumentError, TypeError
        raise Failure, "Identity provider discovery failed"
      end

      def verify_id_token!(token, nonce:, metadata:)
        segments = token.to_s.split(".")
        raise Failure unless segments.length == 3 && token.bytesize <= 32_768
        header = decode_segment(segments[0])
        claims = decode_segment(segments[1])
        raise Failure unless header["alg"] == "RS256" && header["kid"].is_a?(String)

        jwks_uri = safe_https_uri(metadata.fetch("jwks_uri"))
        jwks = Rails.cache.fetch("mcp/oidc-jwks/#{jwks_uri}", expires_in: DISCOVERY_TTL) do
          JSON.parse(http_request(jwks_uri, Net::HTTP::Get.new(jwks_uri), limit: 131_072))
        end
        key = jwks.fetch("keys").find do |candidate|
          candidate["kid"] == header["kid"] && candidate["kty"] == "RSA" &&
            candidate["use"] == "sig" && candidate["alg"] == "RS256"
        end
        raise Failure unless key

        rsa = rsa_from_jwk(key)
        signature = Base64.urlsafe_decode64(segments[2])
        valid_signature = rsa.verify(OpenSSL::Digest.new("SHA256"), signature, "#{segments[0]}.#{segments[1]}")
        now = Time.current.to_i
        audience = claims["aud"]
        valid_audience = audience == client_id || (audience.is_a?(Array) && audience.include?(client_id))
        valid_azp = (claims["azp"].nil? || claims["azp"] == client_id) &&
          (!audience.is_a?(Array) || audience.length == 1 || claims["azp"] == client_id)
        valid = valid_signature && claims["iss"] == issuer && valid_audience && valid_azp &&
          claims["sub"].is_a?(String) && claims["sub"].present? && claims["sub"].bytesize <= 255 &&
          claims["exp"].is_a?(Numeric) && claims["exp"] > now &&
          (!claims.key?("nbf") || (claims["nbf"].is_a?(Numeric) && claims["nbf"] <= now)) &&
          claims["iat"].is_a?(Numeric) && claims["iat"] <= now + CLOCK_SKEW &&
          secure_compare(claims["nonce"].to_s, nonce)
        raise Failure, "Identity token verification failed" unless valid

        { issuer: issuer, subject: claims.fetch("sub") }
      rescue KeyError, JSON::ParserError, ArgumentError, TypeError, OpenSSL::PKey::PKeyError, OpenSSL::OpenSSLError
        raise Failure, "Identity token verification failed"
      end

      def decode_segment(segment)
        JSON.parse(Base64.urlsafe_decode64(segment))
      end

      def rsa_from_jwk(key)
        modulus = OpenSSL::BN.new(Base64.urlsafe_decode64(key.fetch("n")), 2)
        exponent = OpenSSL::BN.new(Base64.urlsafe_decode64(key.fetch("e")), 2)
        sequence = OpenSSL::ASN1::Sequence([ OpenSSL::ASN1::Integer(modulus), OpenSSL::ASN1::Integer(exponent) ])
        OpenSSL::PKey::RSA.new(sequence.to_der)
      end

      def safe_https_uri(value)
        uri = URI.parse(value.to_s)
        raise Failure unless uri.is_a?(URI::HTTPS) && uri.host.present? && !uri.userinfo && !uri.fragment
        uri
      end

      def http_request(uri, request, limit:)
        body = +""
        Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 3, read_timeout: 5, max_retries: 0) do |http|
          http.request(request) do |response|
            raise Failure unless response.is_a?(Net::HTTPSuccess)
            response.read_body do |chunk|
              body << chunk
              raise Failure if body.bytesize > limit
            end
          end
        end
        body
      rescue IOError, SystemCallError, Timeout::Error, SocketError, OpenSSL::SSL::SSLError
        raise Failure, "Identity provider is unavailable"
      end

      def secure_compare(left, right)
        return false unless right.is_a?(String) && left.bytesize == right.bytesize
        ActiveSupport::SecurityUtils.secure_compare(left, right)
      end
    end
  end
end

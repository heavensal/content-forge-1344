require "test_helper"
require_relative "../../support/mcp_method_replacement"

class Mcp::IdentityProviderTest < ActiveSupport::TestCase
  include McpMethodReplacement

  setup do
    @original_env = %w[MCP_OAUTH_ISSUER MCP_LINK_CLIENT_ID].to_h { |key| [ key, ENV[key] ] }
    ENV["MCP_OAUTH_ISSUER"] = "https://identity.example"
    ENV["MCP_LINK_CLIENT_ID"] = "contentforge-link"
    @key = OpenSSL::PKey::RSA.generate(2048)
    @metadata = { "issuer" => ENV["MCP_OAUTH_ISSUER"], "jwks_uri" => "https://identity.example/.well-known/jwks.json" }
    @jwk = {
      "kid" => "key-1", "kty" => "RSA", "use" => "sig", "alg" => "RS256",
      "n" => encode(@key.n.to_s(2)), "e" => encode(@key.e.to_s(2))
    }
  end

  teardown do
    @original_env.each { |key, value| value ? ENV[key] = value : ENV.delete(key) }
  end

  test "verifies RS256 signature and binds issuer subject audience expiry issued-at and nonce" do
    claims = valid_claims
    with_method_result(Mcp::IdentityProvider, :http_request, { "keys" => [ @jwk ] }.to_json) do
      with_method_result(Mcp::IdentityProvider, :discovery, @metadata) do
        assert_equal({ issuer: "https://identity.example", subject: "immutable-subject" },
          Mcp::IdentityProvider.send(:verify_id_token!, signed_token(claims), nonce: "expected-nonce", metadata: @metadata))
      end
    end
  end

  test "rejects bad signature wrong issuer audience expiry future issue time and nonce" do
    bad_signature = signed_token(valid_claims, key: OpenSSL::PKey::RSA.generate(2048))
    invalid_claims = [
      valid_claims.merge("iss" => "https://evil.example"),
      valid_claims.merge("aud" => "another-client"),
      valid_claims.merge("exp" => 1),
      valid_claims.merge("iat" => 10.minutes.from_now.to_i),
      valid_claims.merge("nonce" => "wrong")
    ].map { |claims| signed_token(claims) } + [ bad_signature ]
    with_method_result(Mcp::IdentityProvider, :http_request, { "keys" => [ @jwk ] }.to_json) do
      with_method_result(Mcp::IdentityProvider, :discovery, @metadata) do
        invalid_claims.each do |token|
          assert_raises(Mcp::IdentityProvider::Failure) do
            Mcp::IdentityProvider.send(:verify_id_token!, token, nonce: "expected-nonce", metadata: @metadata)
          end
        end
      end
    end
  end

  test "authorization request includes exact callback S256 challenge nonce and state" do
    ENV["MCP_LINK_CLIENT_SECRET"] = "secret"
    ENV["MCP_LINK_REDIRECT_URI"] = "https://contentforge.example/settings/integrations/mcp/callback"
    with_method_result(Mcp::IdentityProvider, :discovery, { "authorization_endpoint" => "https://identity.example/authorize" }) do
      url = Mcp::IdentityProvider.authorization_url(state: "state-value", nonce: "nonce-value", challenge: "s256-value")
      query = URI.decode_www_form(URI.parse(url).query).to_h
      assert_equal "contentforge-link", query["client_id"]
      assert_equal "https://contentforge.example/settings/integrations/mcp/callback", query["redirect_uri"]
      assert_equal "state-value", query["state"]
      assert_equal "nonce-value", query["nonce"]
      assert_equal "S256", query["code_challenge_method"]
      assert_equal "s256-value", query["code_challenge"]
    end
  ensure
    ENV.delete("MCP_LINK_CLIENT_SECRET")
    ENV.delete("MCP_LINK_REDIRECT_URI")
  end

  private

  def valid_claims
    { "iss" => "https://identity.example", "sub" => "immutable-subject", "aud" => "contentforge-link",
      "exp" => 10.minutes.from_now.to_i, "iat" => Time.current.to_i, "nonce" => "expected-nonce" }
  end

  def signed_token(claims, key: @key)
    header = encode(JSON.generate("alg" => "RS256", "kid" => "key-1", "typ" => "JWT"))
    payload = encode(JSON.generate(claims))
    input = "#{header}.#{payload}"
    "#{input}.#{encode(key.sign(OpenSSL::Digest.new("SHA256"), input))}"
  end

  def encode(value)
    Base64.urlsafe_encode64(value, padding: false)
  end
end

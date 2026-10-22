module Mcp
  class Authentication
    class Unauthorized < StandardError; end
    class Unavailable < StandardError; end
    Context = Data.define(:user, :scopes)

    def self.call(header)
      token = header.to_s.match(/\ABearer ([A-Za-z0-9\-._~+\/=]+)\z/i)&.captures&.first
      raise Unauthorized unless token && token.bytesize <= 8192
      access_token = Doorkeeper::AccessToken.by_token(token)
      raise Unauthorized unless access_token&.accessible? && access_token.resource_owner_id.present?
      Context.new(user: User.find(access_token.resource_owner_id), scopes: access_token.scopes.to_a.freeze)
    rescue ActiveRecord::RecordNotFound
      raise Unauthorized
    end
  end
end

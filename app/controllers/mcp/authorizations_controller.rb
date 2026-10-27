module Mcp
  class AuthorizationsController < ApplicationController
    def index
      @connected = chatgpt_connected?
    end

    def destroy
      current_user.oauth_access_tokens.where(revoked_at: nil).find_each(&:revoke)
      redirect_to settings_mcp_authorizations_path, notice: t("mcp.disconnected")
    end

    private

    def chatgpt_connected?
      current_user.oauth_access_tokens.where(revoked_at: nil).any? do |token|
        token.accessible? || token.refresh_token.present?
      end
    end
  end
end

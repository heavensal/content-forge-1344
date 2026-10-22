module Mcp
  class AuthorizationsController < ApplicationController
    def index
      @tokens = current_user.oauth_access_tokens.includes(:application).order(created_at: :desc)
    end

    def destroy
      token = current_user.oauth_access_tokens.find(params[:id])
      token.revoke
      redirect_to settings_mcp_authorizations_path, notice: "ChatGPT access revoked."
    end
  end
end

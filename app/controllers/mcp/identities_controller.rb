module Mcp
  class IdentitiesController < ApplicationController
    before_action :set_no_store_headers

    def index
      @identities = current_user.mcp_identities.where(revoked_at: nil).order(:created_at)
      @provider_configured = provider_configured?
    end

    def create
      return redirect_to settings_mcp_identities_path, alert: "ChatGPT sign-in linking is not configured yet." unless provider_configured?

      state = SecureRandom.urlsafe_base64(32)
      nonce = SecureRandom.urlsafe_base64(32)
      verifier = SecureRandom.urlsafe_base64(64)
      challenge = Base64.urlsafe_encode64(Digest::SHA256.digest(verifier), padding: false)
      session[IdentityProvider::IDENTITY_SESSION_KEY] = {
        "state" => state, "nonce" => nonce, "verifier" => verifier, "user_id" => current_user.id
      }
      redirect_to IdentityProvider.authorization_url(state: state, nonce: nonce, challenge: challenge), allow_other_host: true
    rescue IdentityProvider::Failure, KeyError, ArgumentError
      session.delete(IdentityProvider::IDENTITY_SESSION_KEY)
      redirect_to settings_mcp_identities_path, alert: "Could not start the ChatGPT sign-in connection."
    end

    def callback
      pending = session.delete(IdentityProvider::IDENTITY_SESSION_KEY)
      return fail_link unless pending.is_a?(Hash) && pending["user_id"] == current_user.id
      return fail_link unless secure_compare(pending["state"], params[:state].to_s)
      return fail_link if params[:error].present? || params[:code].blank?
      return fail_link if params.key?(:iss) && params[:iss] != IdentityProvider.issuer

      identity = IdentityProvider.exchange_and_identify!(code: params[:code], verifier: pending.fetch("verifier"), nonce: pending.fetch("nonce"))
      linked = current_user.mcp_identities.find_or_initialize_by(issuer: identity.fetch(:issuer), subject: identity.fetch(:subject))
      if linked.revoked_at?
        linked.update!(revoked_at: nil)
        redirect_to settings_mcp_identities_path, notice: "ChatGPT sign-in linked again. You can now connect the contentForge MCP server from ChatGPT."
      elsif linked.persisted?
        redirect_to settings_mcp_identities_path, notice: "This sign-in is already linked to your account."
      elsif linked.save
        redirect_to settings_mcp_identities_path, notice: "ChatGPT sign-in linked. You can now connect the contentForge MCP server from ChatGPT."
      else
        redirect_to settings_mcp_identities_path, alert: "This identity is already connected to another contentForge account."
      end
    rescue IdentityProvider::Failure, KeyError, ArgumentError, ActiveRecord::RecordNotUnique
      redirect_to settings_mcp_identities_path, alert: "Could not verify that ChatGPT sign-in. Try again."
    end

    def destroy
      current_user.mcp_identities.where(revoked_at: nil).find(params[:id]).update!(revoked_at: Time.current)
      redirect_to settings_mcp_identities_path, notice: "OAuth identity disconnected."
    end

    private

    def set_no_store_headers
      response.set_header("Cache-Control", "no-store")
      response.set_header("Referrer-Policy", "no-referrer")
    end

    def provider_configured?
      %w[MCP_OAUTH_ISSUER MCP_LINK_CLIENT_ID MCP_LINK_CLIENT_SECRET MCP_LINK_REDIRECT_URI].all? { |key| ENV[key].present? }
    end

    def secure_compare(expected, actual)
      return false unless expected.is_a?(String) && actual.is_a?(String) && expected.bytesize == actual.bytesize
      ActiveSupport::SecurityUtils.secure_compare(expected, actual)
    end

    def fail_link
      redirect_to settings_mcp_identities_path, alert: "The identity connection was cancelled or could not be verified."
    end
  end
end

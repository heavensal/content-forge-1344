# frozen_string_literal: true

class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  # allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  before_action :authenticate_user!, unless: :devise_controller?
  before_action :load_sidebar_websites, if: :use_app_shell?
  before_action :configure_permitted_parameters, if: :devise_controller?

  helper_method :use_app_shell?

  private

  def use_app_shell?
    user_signed_in? && !guest_devise_action?
  end

  def guest_devise_action?
    return false unless devise_controller?

    case controller_name
    when "sessions"
      true
    when "registrations"
      %w[new create].include?(action_name)
    when "passwords", "confirmations", "unlocks"
      true
    else
      false
    end
  end

  def devise_controller?
    is_a?(DeviseController)
  end

  def load_sidebar_websites
    @sidebar_websites = current_user.websites.order(:name)
  end

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [ :name ])
    devise_parameter_sanitizer.permit(:account_update, keys: [ :name ])
  end
end

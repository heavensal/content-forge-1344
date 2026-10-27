# frozen_string_literal: true

class LocalesController < ApplicationController
  skip_before_action :authenticate_user!

  def update
    locale = params[:locale].to_s
    if I18n.available_locales.map(&:to_s).include?(locale)
      cookies.permanent[:locale] = { value: locale, httponly: true, same_site: :lax }
    end

    redirect_to safe_return_path, status: :see_other
  end

  private

  def safe_return_path
    candidate = params[:return_to].to_s
    return root_path unless candidate.start_with?("/") && !candidate.start_with?("//")
    return root_path if candidate.include?("\\")

    candidate
  end
end

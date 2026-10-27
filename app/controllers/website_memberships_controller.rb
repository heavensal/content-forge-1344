# frozen_string_literal: true

class WebsiteMembershipsController < ApplicationController
  before_action :require_admin!
  before_action :set_website

  def create
    user = User.find_by(email: params[:email].to_s.strip.downcase)
    unless user
      redirect_to @website, alert: t("website_membership.alerts.missing_email")
      return
    end

    membership = @website.website_memberships.build(user: user, role: membership_role)
    if membership.save
      redirect_to @website, notice: t("website_membership.notices.assigned", email: user.email)
    else
      redirect_to @website, alert: membership.errors.full_messages.to_sentence
    end
  end

  def destroy
    @website.website_memberships.find(params[:id]).destroy!
    redirect_to @website, notice: t("website_membership.notices.removed")
  end

  private

  def require_admin!
    return if current_user.admin?

    redirect_to websites_path, alert: t("website_membership.alerts.admin_only")
  end

  def set_website
    @website = accessible_websites.find(params[:website_id])
  end

  def membership_role
    role = params[:role].to_s
    WebsiteMembership.roles.key?(role) ? role : "owner"
  end
end

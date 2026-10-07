# frozen_string_literal: true

class WebsiteMembershipsController < ApplicationController
  before_action :require_admin!
  before_action :set_website

  def create
    user = User.find_by(email: params[:email].to_s.strip.downcase)
    unless user
      redirect_to @website, alert: "No account with that email."
      return
    end

    membership = @website.website_memberships.build(user: user, role: membership_role)
    if membership.save
      redirect_to @website, notice: "#{user.email} can now open this website."
    else
      redirect_to @website, alert: membership.errors.full_messages.to_sentence
    end
  end

  def destroy
    @website.website_memberships.find(params[:id]).destroy!
    redirect_to @website, notice: "Website access removed."
  end

  private

  def require_admin!
    return if current_user.admin?

    redirect_to websites_path, alert: "Only an admin can assign a website."
  end

  def set_website
    @website = accessible_websites.find(params[:website_id])
  end

  def membership_role
    role = params[:role].to_s
    WebsiteMembership.roles.key?(role) ? role : "owner"
  end
end

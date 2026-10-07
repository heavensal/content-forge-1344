# frozen_string_literal: true

class WebsitesController < ApplicationController
  before_action :set_website, only: %i[show edit update destroy]
  before_action :require_website_slot, only: %i[new create]

  def index
    @websites = accessible_websites.order(:name)
    return if current_user.admin?

    redirect_to @websites.first if @websites.one?
  end

  def show
  end

  def new
    @website = Website.new
  end

  def create
    @website = Website.new(website_params)
    membership = current_user.admin? ? nil : current_user.website_memberships.build(website: @website, role: "owner")

    if @website.valid? && (membership.nil? || membership.valid?)
      Website.transaction do
        @website.save!
        membership&.save!
      end
      redirect_to @website, notice: "Website was successfully created."
    else
      membership&.errors&.full_messages&.each { |message| @website.errors.add(:base, message) }
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @website.update(website_params)
      redirect_to @website, notice: "Website was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    unless current_user.admin?
      redirect_to @website, alert: "Only an admin can delete a website."
      return
    end

    @website.destroy
    redirect_to websites_url, notice: "Website was successfully deleted."
  end

  private

  def set_website
    @website = accessible_websites.find(params[:id])
  end

  def require_website_slot
    return if current_user.can_create_website?

    redirect_to current_user.websites.first, alert: "You already have a website."
  end

  def website_params
    permitted = params.require(:website).permit(
      :name, :domain, :email, :status, :description,
      :rebuild_webhook_url, :rebuild_webhook_token, :default_locale,
      :imports_articles, :imports_faqs, :imports_reviews
    )
    permitted.delete(:rebuild_webhook_token) if permitted[:rebuild_webhook_token].blank?
    permitted
  end
end

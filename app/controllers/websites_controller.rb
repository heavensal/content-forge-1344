# frozen_string_literal: true

class WebsitesController < ApplicationController
  before_action :set_website, only: %i[show edit update destroy]

  def index
    @websites = current_user.websites.order(:name)
  end

  def show
  end

  def new
    @website = current_user.websites.build
  end

  def create
    @website = current_user.websites.build(website_params)
    if @website.save
      redirect_to @website, notice: "Website was successfully created."
    else
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
    @website.destroy
    redirect_to websites_url, notice: "Website was successfully deleted."
  end

  private

  def set_website
    @website = current_user.websites.find(params[:id])
  end

  def website_params
    params.require(:website).permit(:name, :domain, :status, :description)
  end
end

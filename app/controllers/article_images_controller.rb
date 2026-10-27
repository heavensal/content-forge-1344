# frozen_string_literal: true

class ArticleImagesController < ApplicationController
  before_action :set_website

  def create
    uploaded = CloudinaryImages.upload!(website: @website, io: params[:image])
    render json: {
      url: uploaded.url,
      public_id: uploaded.public_id,
      width: uploaded.width,
      height: uploaded.height
    }
  rescue CloudinaryImages::Error => error
    render json: { error: error.message }, status: :unprocessable_entity
  end

  private

  def set_website
    @website = accessible_websites.find(params[:website_id])
  end
end

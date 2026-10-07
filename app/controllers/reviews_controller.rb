# frozen_string_literal: true

class ReviewsController < ApplicationController
  include ContentTranslation

  before_action :set_website
  before_action :set_review, only: %i[show edit update destroy]

  def index
    @reviews = @website.reviews.ordered
  end

  def show
  end

  def new
    @review = @website.reviews.build(locale: chosen_content_locale)
    prefill_review_translation
  end

  def create
    @review = @website.reviews.build(review_params)
    if @review.save
      redirect_to [ @website, @review ], notice: "Review was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @review.update(review_params)
      redirect_to [ @website, @review ], notice: "Review was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @review.destroy
    redirect_to website_reviews_url(@website), notice: "Review was successfully deleted."
  end

  private

  def set_website
    @website = accessible_websites.find(params[:website_id])
  end

  def set_review
    @review = @website.reviews.find(params[:id])
  end

  def review_params
    params.require(:review).permit(:author, :content, :rating, :status, :published_at, :position, :locale)
  end

  def prefill_review_translation
    source = translation_source(@website.reviews)
    return unless source

    @review.assign_attributes(
      author: source.author,
      content: source.content,
      rating: source.rating,
      position: source.position,
      locale: chosen_content_locale
    )
  end
end

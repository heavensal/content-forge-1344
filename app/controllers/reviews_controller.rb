# frozen_string_literal: true

class ReviewsController < ApplicationController
  before_action :set_website
  before_action :set_review, only: %i[show edit update destroy]

  def index
    @reviews = @website.reviews.ordered
  end

  def show
  end

  def new
    @review = @website.reviews.build
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
    @website = current_user.websites.find(params[:website_id])
  end

  def set_review
    @review = @website.reviews.find(params[:id])
  end

  def review_params
    params.require(:review).permit(:author, :content, :status, :published_at, :position)
  end
end

# frozen_string_literal: true

class ArticlesController < ApplicationController
  before_action :set_website
  before_action :set_article, only: %i[show edit update destroy]

  def index
    @articles = @website.articles.order(updated_at: :desc)
  end

  def show
  end

  def new
    @article = @website.articles.build
  end

  def create
    @article = @website.articles.build(article_params)
    if @article.save
      redirect_to [ @website, @article ], notice: "Article was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @article.update(article_params)
      redirect_to [ @website, @article ], notice: "Article was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @article.destroy
    redirect_to website_articles_url(@website), notice: "Article was successfully deleted."
  end

  private

  def set_website
    @website = current_user.websites.find(params[:website_id])
  end

  def set_article
    @article = @website.articles.find(params[:id])
  end

  def article_params
    params.require(:article).permit(:title, :slug, :description, :status, :published_at, :content)
  end
end

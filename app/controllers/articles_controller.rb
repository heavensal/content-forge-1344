# frozen_string_literal: true

class ArticlesController < ApplicationController
  include ContentTranslation

  before_action :set_website
  before_action :set_article, only: %i[show edit update destroy]

  def index
    @articles = @website.articles.order(updated_at: :desc)
  end

  def show
  end

  def new
    @article = @website.articles.build(locale: chosen_content_locale)
    prefill_article_translation
  end

  def create
    @article = @website.articles.build(article_params)
    if @article.save
      redirect_to [ @website, @article ], notice: t("article.notices.created")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @article.update(article_params)
      redirect_to [ @website, @article ], notice: t("article.notices.updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @article.destroy
    redirect_to website_articles_url(@website), notice: t("article.notices.deleted")
  end

  private

  def set_website
    @website = accessible_websites.find(params[:website_id])
  end

  def set_article
    @article = @website.articles.find(params[:id])
  end

  def article_params
    params.require(:article).permit(
      :title, :slug, :description, :status, :published_at, :content, :locale, :cover_image, :remove_cover_image
    )
  end

  def prefill_article_translation
    source = translation_source(@website.articles)
    return unless source

    @article.assign_attributes(
      title: source.title,
      slug: source.slug,
      description: source.description,
      locale: chosen_content_locale,
      cover_image_public_id: source.cover_image_public_id,
      cover_image_url: source.cover_image_url
    )
    @article.content = source.content.body if source.content.body.present?
  end
end

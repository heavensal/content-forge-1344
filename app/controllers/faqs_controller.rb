# frozen_string_literal: true

class FaqsController < ApplicationController
  include ContentTranslation

  before_action :set_website
  before_action :set_faq, only: %i[show edit update destroy]

  def index
    @faqs = @website.faqs.ordered
  end

  def show
  end

  def new
    @faq = @website.faqs.build(locale: chosen_content_locale)
    prefill_faq_translation
  end

  def create
    @faq = @website.faqs.build(faq_params)
    if @faq.save
      redirect_to [ @website, @faq ], notice: "FAQ was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @faq.update(faq_params)
      redirect_to [ @website, @faq ], notice: "FAQ was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @faq.destroy
    redirect_to website_faqs_url(@website), notice: "FAQ was successfully deleted."
  end

  private

  def set_website
    @website = accessible_websites.find(params[:website_id])
  end

  def set_faq
    @faq = @website.faqs.find(params[:id])
  end

  def faq_params
    params.require(:faq).permit(:question, :slug, :answer, :status, :published_at, :position, :locale)
  end

  def prefill_faq_translation
    source = translation_source(@website.faqs)
    return unless source

    @faq.assign_attributes(
      question: source.question,
      answer: source.answer,
      slug: source.slug,
      position: source.position,
      locale: chosen_content_locale
    )
  end
end

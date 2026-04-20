# frozen_string_literal: true

class ContactFormIntegrationsController < ApplicationController
  before_action :set_website

  def show
    @send_form_url = api_v1_send_form_url
    @example_token = @website.api_token
  end

  private

  def set_website
    @website = current_user.websites.find(params[:website_id])
  end
end

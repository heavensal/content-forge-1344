# frozen_string_literal: true

module Admin
  class BaseController < ApplicationController
    before_action :require_admin!

    private

    def require_admin!
      return if current_user.admin?

      destination = current_user.websites.order(:name).first || root_path
      redirect_to destination, alert: t("admin.alerts.admin_only")
    end
  end
end

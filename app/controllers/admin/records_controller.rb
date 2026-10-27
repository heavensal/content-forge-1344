# frozen_string_literal: true

module Admin
  class RecordsController < BaseController
    ENTITIES = %w[users websites website_memberships articles faqs reviews mcp_changes].freeze

    HIDDEN_COLUMNS = %w[encrypted_password reset_password_token].freeze

    before_action :set_entity

    def index
      @records = relation.order(:id)
    end

    def show
      @record = relation.find(params[:id])
    end

    private

    def set_entity
      @entity = params[:entity].to_s
      raise ActiveRecord::RecordNotFound unless ENTITIES.include?(@entity)

      @label = t("admin.entities.#{@entity}")

      @model = @entity.classify.constantize
      @columns = @model.column_names - HIDDEN_COLUMNS
      @rich_text_columns = rich_text_associations.map { |name| name.to_s.delete_prefix("rich_text_") }
    end

    def relation
      associations = rich_text_associations
      associations.any? ? @model.includes(*associations) : @model.all
    end

    def rich_text_associations
      @model.reflect_on_all_associations(:has_one).filter_map do |association|
        association.name if association.name.to_s.start_with?("rich_text_")
      end
    end
  end
end

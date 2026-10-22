module Mcp
  class ChangesController < ApplicationController
    before_action :load_change

    def show
      @preview = if @change.operation == "create"
        Content.scope(@website, @change.content_type).build(@change.payload)
      else
        Content.scope(@website, @change.content_type).find(@change.record_id).tap do |record|
          record.assign_attributes(@change.payload) if @change.operation == "update"
        end
      end
    end

    def update
      @change.apply!(current_user)
      redirect_to website_path(@website), notice: "Change approved and saved. Website rebuild delivery is asynchronous."
    rescue ArgumentError, ActiveRecord::RecordInvalid => error
      render plain: error.message, status: :conflict
    end

    private

    def load_change
      return head :not_found unless ENV["MCP_ENABLED"] == "true"
      @change = McpChange.where(user: current_user).find(params[:id])
      @website = Content.websites(current_user).find(@change.website_id)
    end
  end
end

# frozen_string_literal: true

module RebuildsWebsite
  extend ActiveSupport::Concern

  class_methods do
    def rebuilds_website_as(content_type)
      @website_rebuild_content_type = content_type.to_s
    end

    def website_rebuild_content_type
      @website_rebuild_content_type
    end
  end

  included do
    after_commit :enqueue_website_rebuild, on: %i[create update destroy]
  end

  private

  def enqueue_website_rebuild
    return if destroyed_by_association

    content_type = self.class.website_rebuild_content_type
    return if content_type.blank?

    website&.schedule_rebuild!(content_type)
  end
end

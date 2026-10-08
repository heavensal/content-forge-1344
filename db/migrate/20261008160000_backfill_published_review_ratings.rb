# frozen_string_literal: true

class BackfillPublishedReviewRatings < ActiveRecord::Migration[8.1]
  def change
    reversible do |dir|
      dir.up do
        # Databases that already ran AddRatingToReviews still have null ratings on
        # reviews published before the column existed. The public API requires 1–5.
        execute <<~SQL.squish
          UPDATE reviews
          SET rating = 5
          WHERE status = 'published' AND rating IS NULL
        SQL
      end
    end
  end
end

# frozen_string_literal: true

class AddRatingToReviews < ActiveRecord::Migration[8.1]
  def change
    add_column :reviews, :rating, :integer

    reversible do |dir|
      dir.up do
        # Published reviews predate this column. A rating of 1–5 is required on the
        # public API, so keep those rows publishable instead of returning null.
        execute <<~SQL.squish
          UPDATE reviews
          SET rating = 5
          WHERE status = 'published' AND rating IS NULL
        SQL
      end
    end
  end
end

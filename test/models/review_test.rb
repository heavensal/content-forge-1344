require "test_helper"

class ReviewTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email: "review-author@example.com", password: "password123", name: "Author")
    @website = @user.websites.create!(name: "ARM", domain: "reviews.example", status: "active")
  end

  test "published review requires a rating from 1 to 5" do
    review = @website.reviews.build(
      author: "Ada",
      content: "Très bien",
      status: "published",
      published_at: Time.current
    )

    assert_not review.valid?
    assert review.errors[:rating].present?

    review.rating = 5
    assert review.valid?

    review.rating = 6
    assert_not review.valid?
  end

  test "draft review may omit the rating" do
    review = @website.reviews.build(status: "draft", rating: nil)
    assert review.valid?
  end
end

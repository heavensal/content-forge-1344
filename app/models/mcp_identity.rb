class McpIdentity < ApplicationRecord
  belongs_to :user
  validates :issuer, :subject, presence: true
  validates :issuer, length: { maximum: 2048 }
  validates :subject, length: { maximum: 255 }
  validates :subject, uniqueness: { scope: :issuer }
end

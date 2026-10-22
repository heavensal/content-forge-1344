class McpIdentity < ApplicationRecord
  belongs_to :user
  validates :issuer, :subject, presence: true
  validates :subject, uniqueness: { scope: :issuer }
end

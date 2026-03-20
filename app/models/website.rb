# frozen_string_literal: true

class Website < ApplicationRecord
  belongs_to :user
  has_many :articles, dependent: :destroy
  has_many :faqs, dependent: :destroy
  has_many :reviews, dependent: :destroy

  has_secure_token :api_token

  enum :status, { active: "active", archived: "archived" }, validate: true

  normalizes :domain, with: ->(d) { d.to_s.strip.downcase }

  validates :name, presence: true
  validates :domain, presence: true, uniqueness: { case_sensitive: false }

  before_validation :ensure_api_token, on: :create

  private

  def ensure_api_token
    regenerate_api_token if api_token.blank?
  end
end

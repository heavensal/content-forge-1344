# frozen_string_literal: true

class WebsiteMembership < ApplicationRecord
  belongs_to :user
  belongs_to :website

  enum :role, { owner: "owner", editor: "editor" }, default: :owner, validate: true

  validates :user_id, uniqueness: { message: "already has a website" }
  validate :admin_uses_role_not_membership
  validate :single_owner

  private

  def admin_uses_role_not_membership
    return if user.blank? || !user.admin?

    errors.add(:user, "is an admin and already sees every website")
  end

  def single_owner
    return unless owner?
    return if website.blank? || website.new_record?

    scope = website.website_memberships.owner
    scope = scope.where.not(id: id) if id.present?
    return unless scope.exists?

    errors.add(:website, "already has an owner")
  end
end

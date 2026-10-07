class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  enum :role, { member: "user", admin: "admin" }, default: :member, validate: true

  has_many :website_memberships, dependent: :destroy
  has_many :websites, through: :website_memberships

  validates :name, presence: true

  def can_create_website?
    admin? || website_memberships.none?
  end
end

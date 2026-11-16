class User < ApplicationRecord
  belongs_to :shop

  has_secure_password

  normalizes :email, with: ->(email) { email.strip.downcase }

  validates :email, presence: true, uniqueness: true
end

class Customer < ApplicationRecord
  belongs_to :shop

  has_many :orders, dependent: :destroy
  has_many :return_orders, dependent: :destroy

  validates :name, :email, presence: true
end

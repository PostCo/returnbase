class Order < ApplicationRecord
  belongs_to :shop
  belongs_to :customer

  has_many :line_items, class_name: "OrderLineItem", dependent: :destroy
  has_many :return_orders, dependent: :destroy

  validates :number, presence: true
end

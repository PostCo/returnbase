class Variant < ApplicationRecord
  belongs_to :product

  has_many :inventory_levels, dependent: :destroy

  monetize :price_cents, with_model_currency: :currency

  validates :sku, :title, presence: true

  def display_name
    "#{product.title} / #{title}"
  end
end

class Shop < ApplicationRecord
  has_many :users, dependent: :destroy
  has_many :locations, dependent: :destroy
  has_many :customers, dependent: :destroy
  has_many :products, dependent: :destroy
  has_many :orders, dependent: :destroy
  has_many :shipping_methods, dependent: :destroy
  has_many :return_orders, dependent: :destroy
  has_many :integrations, dependent: :destroy
  has_one :store_box_integration
  has_one :parcel_dock_integration
  belongs_to :default_location, class_name: "Location", optional: true

  validates :name, presence: true
  validate :default_location_is_active

  # Where new shopper returns go.
  def return_location
    default_location || locations.active.order(:id).first
  end

  private

  def default_location_is_active
    return unless default_location

    errors.add(:default_location, "must be an active location of this shop") if default_location.shop_id != id || default_location.archived?
  end
end

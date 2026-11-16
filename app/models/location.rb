class Location < ApplicationRecord
  include FlagShihTzu

  belongs_to :shop

  has_many :inventory_levels, dependent: :destroy
  has_many :return_orders, dependent: :restrict_with_error

  # Warehouse integrations claim a location with a flag.
  has_flags 1 => :store_box_warehouse,
    2 => :parcel_dock_facility,
    :flag_query_mode => :bit_operator

  scope :active, -> { where(archived_at: nil) }

  validates :name, presence: true
  validate :default_stays_active

  def archived?
    archived_at.present?
  end

  private

  def default_stays_active
    errors.add(:base, "The default return location cannot be archived") if archived? && shop.default_location_id == id
  end
end

class ReturnOrder < ApplicationRecord
  include ReturnOrder::Timeline
  include ReturnOrder::Filterable

  belongs_to :shop
  belongs_to :order
  belongs_to :customer
  belongs_to :location
  belongs_to :shipping_method

  has_many :items, class_name: "ReturnItem", dependent: :destroy
  has_many :exchanges, dependent: :destroy
  has_many :refunds, dependent: :destroy
  has_one :shipment, dependent: :destroy
  has_one :store_box_return, class_name: "StoreBox::Return", dependent: :destroy
  has_many :store_box_send_attempts, class_name: "StoreBox::SendAttempt", dependent: :destroy

  scope :store_box_send_failed, -> { where(id: StoreBox::SendAttempt.select(:return_order_id)).where.missing(:store_box_return) }

  before_validation :assign_number, on: :create

  # The one place that lists every status and the moves between them.
  # Each event also writes a status_changed timeline event (ReturnOrder::Timeline).
  enum :status, {
    submitted: 0,
    approved: 10,
    rejected: 20,
    in_transit: 30,
    received: 40,
    resolved: 50,
    cancelled: 60,
  } do
    event :approve do
      transition submitted: :approved
    end

    event :reject do
      transition [:submitted, :received] => :rejected
    end

    event :mark_in_transit do
      transition approved: :in_transit
    end

    # Own-postage returns have no carrier events, so they are received straight from approved.
    event :receive do
      transition [:approved, :in_transit] => :received
    end

    event :resolve do
      transition received: :resolved
    end

    event :cancel do
      transition [:submitted, :approved] => :cancelled
    end
  end

  delegate :own_postage?, :label?, to: :shipping_method

  def store_box_status
    store_box_return&.status || ("send_failed" if store_box_send_attempts.any?)
  end

  def movable?
    submitted? || approved?
  end

  def editable?
    submitted? || approved? || in_transit?
  end

  def posting_instructions
    destination = [location.name, location.address.presence || location.city].compact_blank.join(", ")
    "Post your parcel to #{destination}. Write #{number} on the parcel and keep your proof of postage."
  end

  private

  def assign_number
    self.number ||= "R#{1000 + shop.return_orders.count + 1}"
  end
end

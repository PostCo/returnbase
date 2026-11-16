class TimelineEvent < ApplicationRecord
  belongs_to :return_order

  enum :kind, {
    submitted: 0,
    status_changed: 1,
    shipment_created: 2,
    exchange_reserved: 3,
    refunded: 4,
    items_edited: 5,
    exchange_fulfilled: 6,
    carrier_event: 7,
    sent_to_warehouse: 8,
    warehouse_send_failed: 9,
    warehouse_inspected: 10,
    cancelled: 11,
    restocked: 12,
    label_requested: 13,
    label_failed: 14,
    moved: 15,
    items_decided: 16,
  }
end

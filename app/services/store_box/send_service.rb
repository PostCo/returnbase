# Creates the return at StoreBox. StoreBox::SendJob runs it after approval (own postage) or after the label is bought
# (label returns), and the merchant's Retry runs it again. A failure is kept as a StoreBox::SendAttempt.
class StoreBox::SendService < ApplicationService
  def initialize(return_order:)
    @return_order = return_order
  end

  def call
    raise Failure, "This return is already at StoreBox" if return_order.store_box_return
    raise Failure, "StoreBox is not active" unless integration&.active?

    mapping = integration.location_mappings.find_by(location: return_order.location)
    raise Failure, "#{return_order.location.name} does not send to a StoreBox warehouse" unless mapping

    remote = integration.client.create_return(reference: return_order.number, warehouse_id: mapping.warehouse_id, items: items)
    store_box_return = return_order.create_store_box_return!(
      store_box_integration: integration, remote_id: remote["id"], warehouse_id: mapping.warehouse_id, status: :pending,
    )
    return_order.record_event(:sent_to_warehouse, warehouse: "StoreBox", remote_id: remote["id"])
    result(success: true, payload: store_box_return)
  rescue VendorClient::Error => e
    integration.send_attempts.create!(return_order: return_order, error: e.message)
    return_order.record_event(:warehouse_send_failed, warehouse: "StoreBox", error: e.message)
    raise Failure, "StoreBox did not take the return: #{e.message}"
  end

  private

  attr_reader :return_order

  def integration
    return_order.shop.store_box_integration
  end

  def items
    return_order.items.includes(:variant).map { |item| { sku: item.variant.sku, quantity: item.quantity, reason: item.reason } }
  end
end

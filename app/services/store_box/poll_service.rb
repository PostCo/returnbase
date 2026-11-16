# Reads one return back from StoreBox. When StoreBox has the parcel, the return is received. When StoreBox has graded
# every item, the merchant's result mapping sets each item's condition and decides whether the return is resolved now or
# left for manual review.
class StoreBox::PollService < ApplicationService
  def initialize(store_box_return:)
    @store_box_return = store_box_return
  end

  def call
    remote = integration.client.find_return(store_box_return.remote_id)
    ReturnOrder.transaction do
      receive if store_box_return.pending? && %w[received inspected].include?(remote["status"])
      apply_results(remote["items"]) if remote["status"] == "inspected"
    end
    result(success: true, payload: store_box_return)
  rescue VendorClient::Error => e
    raise Failure, "Could not read #{store_box_return.remote_id} from StoreBox: #{e.message}"
  end

  private

  attr_reader :store_box_return

  delegate :return_order, to: :store_box_return

  def integration
    store_box_return.store_box_integration
  end

  def receive
    store_box_return.received!
    ReturnOrders::ReceiveService.call!(return_order: return_order) if return_order.can_receive?
  end

  def grade_items(results)
    items = return_order.items.includes(:variant).index_by { |item| item.variant.sku }
    results.each { |graded| items[graded["sku"]]&.update!(condition: integration.condition_for(graded["result"])) }
  end

  def apply_results(items)
    results = items.map { |item| item.slice("sku", "quantity", "result") }
    action = integration.action_for(results.map { |item| item["result"] })
    grade_items(results)
    store_box_return.update!(status: :inspected, results: results, action: action)
    return_order.record_event(:warehouse_inspected, warehouse: "StoreBox", results: results.map { |item| item["result"] }, action: action)
    ReturnOrders::ResolveService.call!(return_order: return_order) if action == "resolve" && return_order.can_resolve?
  end
end

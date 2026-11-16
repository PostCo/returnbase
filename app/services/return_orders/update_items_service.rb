# Replaces the items of a return that has not arrived and keeps the exchange reservations in step.
class ReturnOrders::UpdateItemsService < ApplicationService
  def initialize(return_order:, items:)
    @return_order = return_order
    @items = items
  end

  def call
    raise Failure, "Items can no longer be edited" unless return_order.editable?

    ReturnOrder.transaction do
      ReturnOrders::ReplaceItemsService.call!(return_order: return_order, items: items)
      ReturnOrders::ReserveExchangesService.call!(return_order: return_order) unless return_order.submitted?
      return_order.record_event(:items_edited, item_count: return_order.items.count)
    end
    result(success: true, payload: return_order)
  end

  private

  attr_reader :return_order, :items
end

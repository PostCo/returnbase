class ReturnOrders::SubmitService < ApplicationService
  def initialize(order:, shipping_method:, items:)
    @order = order
    @shipping_method = shipping_method
    @items = items
  end

  def call
    return_order = ReturnOrder.transaction do
      created = order.shop.return_orders.create!(
        order: order, customer: order.customer, shipping_method: shipping_method,
        location: order.shop.return_location,
      )
      ReturnOrders::ReplaceItemsService.call!(return_order: created, items: items)
      created
    end

    ReturnMailer.submitted(return_order).deliver_now
    result(success: true, payload: return_order)
  end

  private

  attr_reader :order, :shipping_method, :items
end

class ReturnOrders::SendToWarehouseService < ApplicationService
  def initialize(return_order:)
    @return_order = return_order
  end

  def call
    StoreBox::SendJob.perform_later(return_order) if send_to_store_box?
    result(success: true, payload: return_order)
  end

  private

  attr_reader :return_order

  def send_to_store_box?
    return_order.shop.store_box_integration&.active? && return_order.location.store_box_warehouse?
  end
end

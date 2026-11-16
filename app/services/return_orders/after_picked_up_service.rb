class ReturnOrders::AfterPickedUpService < ApplicationService
  def initialize(return_order:)
    @return_order = return_order
  end

  def call
    return result(success: true) unless return_order.shop.refund_on_carrier_pickup?
    return result(success: true) if warehouse_owned?

    ReturnOrders::RefundService.call!(return_order: return_order)
    result(success: true)
  end

  private

  attr_reader :return_order

  def warehouse_owned?
    # The warehouses that inspect returns, by location flag. ParcelDock's facility is still missing.
    inspecting_warehouse_flags = [:store_box_warehouse]

    inspecting_warehouse_flags.any? { |flag| return_order.location.public_send(:"#{flag}?") }
  end
end

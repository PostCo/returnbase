require "test_helper"

class ReturnFlowTest < ActiveSupport::TestCase
  include ReturnFixtures

  test "approving a label return requests the label, and the callback stores it and emails the shopper" do
    build_return
    outcome = approve_with_label

    assert outcome.success?, outcome.errors.full_messages.to_sentence
    assert_equal "approved", @return_order.reload.status
    assert_equal "http://carrier.test/labels/R1001", @return_order.shipment.label_url
    assert_includes ReturnMailer.deliveries.last.body.to_s, "http://carrier.test/labels/R1001"
    assert_includes ReturnMailer.deliveries[-2].body.to_s, "label will follow by email"
  end

  test "an own-postage return is approved without a label and received from approved" do
    build_return(kind: :own_postage)

    assert ReturnOrders::ApproveService.call(return_order: @return_order).success?
    assert_nil @return_order.reload.shipment
    assert_includes ReturnMailer.deliveries.last.body.to_s, "Post your parcel to Hub, Leeds"
    assert ReturnOrders::ReceiveService.call(return_order: @return_order).success?
    assert @return_order.reload.received?
  end

  test "pickup refunds straight away only when the shop setting is on" do
    [true, false].each do |setting|
      build_return(refund_on_pickup: setting)
      approve_with_label
      Shipments::PickedUpService.call(tracking_number: @return_order.reload.shipment.tracking_number)

      assert @return_order.reload.in_transit?
      assert_equal setting ? 1 : 0, @return_order.refunds.count
    end
  end

  test "resolving after a refund on pickup does not refund twice" do
    build_return(refund_on_pickup: true)
    approve_with_label
    Shipments::PickedUpService.call(tracking_number: @return_order.reload.shipment.tracking_number)
    ReturnOrders::ReceiveService.call(return_order: @return_order)
    ReturnOrders::ResolveService.call(return_order: @return_order)

    assert @return_order.reload.resolved?
    assert_equal [2000], @return_order.refunds.map(&:amount_cents)
  end

  test "resolving after an item edit refunds the difference from the pickup refund" do
    build_return(refund_on_pickup: true)
    approve_with_label
    Shipments::PickedUpService.call(tracking_number: @return_order.reload.shipment.tracking_number)
    ReturnOrders::UpdateItemsService.call(return_order: @return_order, items: [item(quantity: 2)])
    ReturnOrders::ReceiveService.call(return_order: @return_order)
    ReturnOrders::ResolveService.call(return_order: @return_order)

    assert_equal 4000, @return_order.reload.refunds.sum(:amount_cents)
  end

  test "editing items keeps the exchange reservation in step and resolving fulfils it" do
    build_return(kind: :own_postage, resolution: :exchange)
    ReturnOrders::ApproveService.call(return_order: @return_order)
    assert_equal [1], @return_order.reload.exchanges.flat_map(&:reservations).map(&:quantity)

    assert ReturnOrders::UpdateItemsService.call(return_order: @return_order, items: [item(:exchange, quantity: 2)]).success?
    assert_equal [2], @return_order.reload.exchanges.flat_map(&:reservations).map(&:quantity)

    ReturnOrders::ReceiveService.call(return_order: @return_order)
    ReturnOrders::ResolveService.call(return_order: @return_order)

    assert_equal ["fulfilled"], @return_order.reload.exchanges.map(&:status)
    assert_equal 0, @medium.inventory_levels.first.available
  end

  test "resolving with restock on puts the items back at the return location and records it" do
    build_return(kind: :own_postage, restock: true)
    @small.inventory_levels.create!(location: @location, available: 3)
    ReturnOrders::ApproveService.call(return_order: @return_order)
    ReturnOrders::ReceiveService.call(return_order: @return_order)

    assert ReturnOrders::ResolveService.call(return_order: @return_order).success?
    assert_equal 4, @small.inventory_levels.find_by!(location: @location).available
    event = @return_order.timeline_events.restocked.sole
    assert_equal({ "restocked" => [{ "sku" => "TEE-S", "quantity" => 1, "available" => 4 }], "skipped" => [] }, event.data)
  end

  test "resolving with restock off leaves stock alone" do
    build_return(kind: :own_postage)
    ReturnOrders::ApproveService.call(return_order: @return_order)
    ReturnOrders::ReceiveService.call(return_order: @return_order)
    ReturnOrders::ResolveService.call(return_order: @return_order)

    assert_empty @small.inventory_levels
    assert_equal({ "restocked" => [], "skipped" => [{ "sku" => "TEE-S", "quantity" => 1 }] }, @return_order.timeline_events.restocked.sole.data)
  end

  test "an item graded not restockable is skipped and listed on the timeline" do
    build_return(kind: :own_postage, restock: true)
    ReturnOrders::ApproveService.call(return_order: @return_order)
    ReturnOrders::ReceiveService.call(return_order: @return_order)
    @return_order.items.first.not_restockable!
    ReturnOrders::ResolveService.call(return_order: @return_order)

    assert_empty @small.inventory_levels
    assert_equal({ "restocked" => [], "skipped" => [{ "sku" => "TEE-S", "quantity" => 1 }] }, @return_order.timeline_events.restocked.sole.data)
  end

  test "editing is refused once the return has arrived" do
    build_return(kind: :own_postage)
    ReturnOrders::ApproveService.call(return_order: @return_order)
    ReturnOrders::ReceiveService.call(return_order: @return_order)

    assert ReturnOrders::UpdateItemsService.call(return_order: @return_order, items: [item]).failed?
  end
end

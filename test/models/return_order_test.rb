require "test_helper"

class ReturnOrderTest < ActiveSupport::TestCase
  setup do
    @shop = Shop.create!(name: "Test Shop")
    customer = @shop.customers.create!(name: "Ada", email: "ada@example.com")
    @return_order = @shop.return_orders.create!(
      order: @shop.orders.create!(customer: customer, number: "#1", placed_at: Time.current),
      customer: customer,
      location: @shop.locations.create!(name: "Hub"),
      shipping_method: @shop.shipping_methods.create!(kind: :label, name: "Label", carrier_name: "Parcel Express"),
    )
  end

  test "a new return is submitted, numbered and on the timeline" do
    assert @return_order.submitted?
    assert_equal "R1001", @return_order.number
    assert_equal %w[submitted], @return_order.timeline_events.map(&:kind)
  end

  test "events follow the allowed transitions and write a timeline entry" do
    @return_order.approve
    @return_order.mark_in_transit

    assert @return_order.in_transit?
    last = @return_order.timeline_events.last
    assert_equal({ "from" => "approved", "to" => "in_transit" }, last.data)
  end

  test "events reject moves the state machine does not allow" do
    assert_not @return_order.can_receive?
    assert_raises(RuntimeError) { @return_order.receive! }
    assert @return_order.submitted?
  end

  test "a shop does not refund on carrier pickup by default" do
    assert_not @shop.refund_on_carrier_pickup
  end
end

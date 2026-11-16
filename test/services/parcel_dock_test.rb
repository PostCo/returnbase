require "test_helper"

class ParcelDockTest < ActiveSupport::TestCase
  include ReturnFixtures

  test "with ParcelDock enabled, a label return is requested from ParcelDock and goes to the facility once the label arrives" do
    build_return(kind: :label)
    facility = @shop.locations.create!(name: "ParcelDock PD-01", parcel_dock_facility: true)
    @shop.create_parcel_dock_integration!(api_key: "pd_key", status: :enabled)
    shipping = ReturnFixtures::FakeShipping.new

    outcome = approve_and_request_label(shipping)

    assert outcome.success?, outcome.errors.full_messages.to_sentence
    assert_equal ["parceldock", "pd_key"], shipping.requests.last.values_at(:carrier, :carrier_api_key)
    assert_equal @location, @return_order.reload.location

    label_created(carrier: "parceldock", tracking_number: "PD00000001")
    assert_equal "PD00000001", @return_order.reload.shipment.tracking_number
    assert_equal facility, @return_order.location
  end

  test "a ParcelDock return the merchant moved keeps its new location when the new label arrives" do
    build_return(kind: :label)
    @shop.locations.create!(name: "ParcelDock PD-01", parcel_dock_facility: true)
    @shop.create_parcel_dock_integration!(api_key: "pd_key", status: :enabled)
    other = @shop.locations.create!(name: "Leeds Returns")
    shipping = ReturnFixtures::FakeShipping.new
    approve_and_request_label(shipping)
    label_created(carrier: "parceldock", tracking_number: "PD00000001")

    ShippingClient.stub(:new, shipping) { ReturnOrders::MoveService.call!(return_order: @return_order, location: other) }
    label_created(carrier: "parceldock", tracking_number: "PD00000002")

    assert_equal other, @return_order.reload.location
    assert_equal "PD00000002", @return_order.shipment.tracking_number
  end

  test "with ParcelDock disabled, the label is requested from QuickPost" do
    build_return(kind: :label)
    @shop.create_parcel_dock_integration!(api_key: "pd_key", status: :disabled)
    shipping = ReturnFixtures::FakeShipping.new

    assert approve_with_label(shipping: shipping).success?
    assert_equal "quickpost", shipping.requests.last[:carrier]
    assert_match(/\AQP/, @return_order.reload.shipment.tracking_number)
  end
end

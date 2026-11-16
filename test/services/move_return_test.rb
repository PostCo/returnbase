require "test_helper"

class MoveReturnTest < ActiveSupport::TestCase
  include ReturnFixtures

  setup do
    ReturnMailer.deliveries.clear
  end

  def depot(stock: 0)
    @depot = @shop.locations.create!(name: "Depot", city: "York", address: "5 Dock Road, York")
    @medium.inventory_levels.create!(location: @depot, available: stock)
    @depot
  end

  def move_to(location)
    ReturnOrders::MoveService.call(return_order: @return_order, location: location)
  end

  test "a submitted return changes location and nothing else" do
    build_return(resolution: :exchange)
    ReturnMailer.deliveries.clear

    outcome = move_to(depot)

    assert outcome.success?, outcome.errors.full_messages.to_sentence
    assert_equal @depot, @return_order.reload.location
    assert_empty @return_order.exchanges
    assert_equal({ "from" => "Hub", "to" => "Depot" }, @return_order.timeline_events.moved.last.data)
    assert_empty ReturnMailer.deliveries
  end

  test "an approved exchange return takes its stock hold to the new location" do
    build_return(kind: :own_postage, resolution: :exchange)
    ReturnOrders::ApproveService.call(return_order: @return_order)

    assert move_to(depot(stock: 1)).success?

    assert_equal [@depot.id], Reservation.pluck(:location_id)
    assert_equal 1, @return_order.reload.exchanges.count
  end

  test "a move to a location without the exchange stock fails and changes nothing" do
    build_return(kind: :own_postage, resolution: :exchange)
    ReturnOrders::ApproveService.call(return_order: @return_order)

    outcome = move_to(depot(stock: 0))

    assert outcome.failed?
    assert_equal ["Not enough stock of #{@medium.display_name} at Depot"], outcome.errors.full_messages
    assert_equal @location, @return_order.reload.location
    assert_equal [@location.id], Reservation.pluck(:location_id)
    assert_empty @return_order.timeline_events.moved
  end

  test "an approved label return gets a new label, and the old label request is replaced" do
    build_return
    shipping = FakeShipping.new
    approve_with_label(shipping: shipping)
    ReturnMailer.deliveries.clear

    outcome = ShippingClient.stub(:new, shipping) { move_to(depot) }

    assert outcome.success?, outcome.errors.full_messages.to_sentence
    shipment = @return_order.reload.shipment
    assert shipment.pending?
    assert_equal "lbl_2", shipment.label_request_id
    assert_nil shipment.label_url
    assert_equal 2, shipping.requests.size
    assert_empty ReturnMailer.deliveries

    label_created
    assert_equal "Your prepaid label for return #{@return_order.number}", ReturnMailer.deliveries.last.subject
  end

  test "an approved own-postage return emails the new posting address" do
    build_return(kind: :own_postage)
    ReturnOrders::ApproveService.call(return_order: @return_order)
    ReturnMailer.deliveries.clear

    assert move_to(depot).success?

    email = ReturnMailer.deliveries.last
    assert_equal ["ada@example.com"], email.to
    assert_includes email.body.to_s, "Post your parcel to Depot, 5 Dock Road, York"
  end

  test "only submitted or approved returns move, and only to an active location of the shop" do
    build_return(kind: :own_postage)
    depot
    ReturnOrders::ApproveService.call(return_order: @return_order)

    @depot.update!(archived_at: Time.current)
    assert_equal ["Choose an active location"], move_to(@depot).errors.full_messages
    assert_equal ["The return is already at Hub"], move_to(@location).errors.full_messages

    @depot.update!(archived_at: nil)
    ReturnOrders::ReceiveService.call(return_order: @return_order)
    assert_equal ["Only submitted or approved returns can be moved"], move_to(@depot).errors.full_messages
  end
end

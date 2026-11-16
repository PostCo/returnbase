require "test_helper"

class ResolveItemsTest < ActiveSupport::TestCase
  include ReturnFixtures

  setup do
    build_return(kind: :own_postage, restock: true)
    order = @return_order.order
    @tee_level = @small.inventory_levels.create!(location: @location, available: 3)
    items = [item]
    { "SOCK" => [1500, :refund], "CAP" => [2000, :exchange], "HAT" => [2500, :exchange] }.each do |name, (price, resolution)|
      product = @shop.products.create!(title: name)
      small = product.variants.create!(sku: "#{name}-S", title: "S", price_cents: price, currency: "USD")
      medium = product.variants.create!(sku: "#{name}-M", title: "M", price_cents: price, currency: "USD")
      medium.inventory_levels.create!(location: @location, available: 2)
      order.line_items.create!(variant: small, quantity: 1, price_cents: price, currency: "USD")
      items << { sku: small.sku, quantity: 1, reason: "too_small", resolution: resolution.to_s, exchange_sku: (medium.sku if resolution == :exchange) }
    end
    ReturnOrders::UpdateItemsService.call!(return_order: @return_order, items: items)
    ReturnOrders::ApproveService.call!(return_order: @return_order)
    ReturnOrders::ReceiveService.call!(return_order: @return_order)
    @items = @return_order.reload.items.includes(:variant).index_by { |item| item.variant.sku }
    ReturnMailer.deliveries.clear
  end

  def decide(sku, outcome, restock = nil)
    { item_id: @items.fetch(sku).id, outcome: outcome, restock: restock }
  end

  def level(sku)
    Variant.find_by!(sku: sku).inventory_levels.find_by(location: @location)
  end

  test "a partial decision refunds what was accepted, restocks what was ticked, ships one exchange and releases the other" do
    outcome = ReturnOrders::ResolveService.call(return_order: @return_order, decisions: [
      decide("TEE-S", "accepted", true), decide("SOCK-S", "rejected", true), decide("CAP-S", "accepted", false), decide("HAT-S", "rejected"),
    ])

    assert outcome.success?, outcome.errors.full_messages.to_sentence
    assert @return_order.reload.resolved?
    assert_equal [2000], @return_order.refunds.map(&:amount_cents)
    assert_equal({ "TEE-S" => [["accepted", true]], "SOCK-S" => [["rejected", false]], "CAP-S" => [["accepted", false]], "HAT-S" => [["rejected", false]] },
                 @return_order.items.includes(:variant).group_by { |i| i.variant.sku }.transform_values { |is| is.map { |i| [i.outcome, i.restock] } })
    assert_equal 4, @tee_level.reload.available
    assert_nil level("SOCK-S")
    assert_nil level("CAP-S")
    assert_equal({ "restocked" => [{ "sku" => "TEE-S", "quantity" => 1, "available" => 4 }], "skipped" => [{ "sku" => "CAP-S", "quantity" => 1 }] },
                 @return_order.timeline_events.restocked.sole.data)
    assert_equal({ "accepted" => [{ "sku" => "TEE-S", "quantity" => 1, "restock" => true }, { "sku" => "CAP-S", "quantity" => 1, "restock" => false }],
                   "rejected" => [{ "sku" => "SOCK-S", "quantity" => 1 }, { "sku" => "HAT-S", "quantity" => 1 }] },
                 @return_order.timeline_events.items_decided.sole.data)

    assert_equal ["CAP-M"], @return_order.exchanges.map { |exchange| exchange.variant.sku }
    assert_equal ["fulfilled"], @return_order.exchanges.map(&:status)
    assert_equal 1, level("CAP-M").available
    assert_equal 2, level("HAT-M").available
    assert_equal 0, Reservation.where(variant: Variant.where(sku: %w[CAP-M HAT-M])).count

    refunded = ReturnMailer.deliveries.find { |mail| mail.subject.include?("refund") }
    assert_includes refunded.body.to_s, "1 x SOCK / S (refund) - not accepted"
    assert_not_includes refunded.body.to_s, "TEE / S (refund) - not accepted"
  end

  test "rejecting every item ends the return rejected, releases the exchange holds and emails the shopper" do
    decisions = @items.values.map { |item| { item_id: item.id, outcome: "rejected", restock: true } }
    assert ReturnOrders::ResolveService.call(return_order: @return_order, decisions: decisions).success?

    assert @return_order.reload.rejected?
    assert_empty @return_order.refunds
    assert_empty @return_order.exchanges
    assert_equal 0, Reservation.count
    assert_equal [false] * 4, @return_order.items.map(&:restock)
    assert_equal 3, @tee_level.reload.available
    assert_equal ["Your return R1001 was not accepted"], ReturnMailer.deliveries.map(&:subject)
  end

  test "rejecting a received return rejects each item" do
    assert ReturnOrders::RejectService.call(return_order: @return_order).success?

    assert @return_order.reload.rejected?
    assert_equal ["rejected"], @return_order.items.map(&:outcome).uniq
    assert_equal 1, ReturnMailer.deliveries.size
  end

  test "rejecting a submitted return emails the shopper" do
    build_return(kind: :own_postage)
    ReturnMailer.deliveries.clear

    assert ReturnOrders::RejectService.call(return_order: @return_order).success?
    assert @return_order.reload.rejected?
    assert_equal ["Your return R1001 was not accepted"], ReturnMailer.deliveries.map(&:subject)
  end

  test "without decisions every item is accepted with its default restock choice" do
    @items.fetch("HAT-S").not_restockable!

    assert ReturnOrders::ResolveService.call(return_order: @return_order).success?

    assert_equal ["accepted"], @return_order.reload.items.map(&:outcome).uniq
    assert_equal({ "TEE-S" => true, "SOCK-S" => true, "CAP-S" => true, "HAT-S" => false }, @return_order.items.includes(:variant).to_h { |i| [i.variant.sku, i.restock] })
    assert_equal ["CAP-M", "HAT-M"], @return_order.exchanges.map { |e| e.variant.sku }.sort
  end

  test "decisions must cover each item once" do
    [
      [decide("TEE-S", "accepted")],
      @items.values.map { |item| { item_id: item.id, outcome: "accepted" } } + [decide("TEE-S", "rejected")],
      @items.values.map { |item| { item_id: item.id, outcome: "maybe" } },
    ].each do |decisions|
      outcome = ReturnOrders::ResolveService.call(return_order: @return_order, decisions: decisions)
      assert outcome.failed?
    end

    assert @return_order.reload.received?
    assert_equal [nil], @return_order.items.map(&:outcome).uniq
  end

  test "a pickup refund is kept when an item is rejected later" do
    @return_order.update!(status: :in_transit)
    ReturnOrders::RefundService.call!(return_order: @return_order)
    assert_equal [3500], @return_order.refunds.map(&:amount_cents)
    @return_order.update!(status: :received)

    ReturnOrders::ResolveService.call!(return_order: @return_order, decisions: [
      decide("TEE-S", "accepted"), decide("SOCK-S", "rejected"), decide("CAP-S", "accepted"), decide("HAT-S", "accepted"),
    ])

    assert_equal [3500], @return_order.refunds.reload.map(&:amount_cents)
  end
end

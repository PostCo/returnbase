# Demo data: two ordinary shops and one large merchant, with returns in every status.
# Loaded by bin/setup (db:prepare) and bin/reset (db:setup). Skips itself when shops already exist.
require "active_support/testing/time_helpers"

return if Shop.exists?

module DemoSeeds
  extend ActiveSupport::Testing::TimeHelpers

  RANDOM = Random.new(7)
  DEMO_PASSWORD = "returnbase"

  SHOPS = [
    {
      name: "Kopi Threads", currency: "MYR", refund_on_carrier_pickup: true, restock_on_resolve: true,
      locations: [["Kuala Lumpur Returns Hub", "Kuala Lumpur"], ["Penang Returns", "George Town"]],
      products: [
        ["Classic Kopi Tee", 5900, %w[S M L]], ["Pandan Hoodie", 12_900, %w[M L XL]],
        ["Tote Bag", 2900, %w[Natural Black]], ["Linen Shirt", 8900, %w[S M L]]
      ],
      carrier: "QuickPost",
    },
    {
      name: "Lumen Home", currency: "GBP", refund_on_carrier_pickup: false, restock_on_resolve: false,
      locations: [["Manchester Returns", "Manchester"], ["Leeds Returns", "Leeds"]],
      products: [
        ["Arc Floor Lamp", 14_900, %w[Brass Black]], ["Ceramic Table Lamp", 6900, %w[White Sage Sand]],
        ["Linen Shade", 2900, %w[Small Large]], ["Smart Bulb 4-pack", 3500, %w[Warm Cool]]
      ],
      carrier: "QuickPost",
    },
    {
      name: "Harbour & Pine", currency: "USD", refund_on_carrier_pickup: false, restock_on_resolve: true,
      locations: [
        ["Portland Returns", "Portland, ME"], ["Boston Returns", "Boston, MA"], ["New York Returns", "New York, NY"],
        ["Philadelphia Returns", "Philadelphia, PA"], ["Chicago Returns", "Chicago, IL"], ["Seattle Returns", "Seattle, WA"],
        ["Los Angeles Returns", "Los Angeles, CA"], ["Austin Returns", "Austin, TX"], ["Denver Returns", "Denver, CO"]
      ],
      products: [
        ["Cable Knit Sweater", 12_800, %w[S M L XL]], ["Waxed Field Jacket", 24_800, %w[S M L XL]],
        ["Merino Base Layer", 8800, %w[S M L]], ["Chino Trouser", 9800, %w[30 32 34]],
        ["Canvas Overshirt", 11_800, %w[S M L XL]], ["Wool Beanie", 3800, ["One Size"]]
      ],
      carrier: "QuickPost",
    },
  ].freeze

  NAMES = %w[Aisha Ben Chloe Daniel Elena Farid Grace Hiro Imani Jonas Kavya Liam].freeze
  SURNAMES = %w[Tan Okafor Lindqvist Reyes Hartley Novak Ibrahim Moreau Singh Walsh Park Costa].freeze

  STATUS_PLAN = { submitted: 8, approved: 7, rejected: 4, in_transit: 7, received: 5, resolved: 7, cancelled: 2 }.freeze
  EVENTS = {
    submitted: [], approved: [:approve], rejected: [:reject],
    in_transit: %i[approve mark_in_transit], received: %i[approve mark_in_transit receive],
    resolved: %i[approve mark_in_transit receive resolve], cancelled: [:cancel]
  }.freeze

  def self.run
    SHOPS.each { |config| seed_shop(config) }
    travel_back
    summary
  end

  def self.seed_shop(config)
    shop = Shop.create!(config.slice(:name, :currency, :refund_on_carrier_pickup, :restock_on_resolve))
    shop.users.create!(email: "owner@#{config[:name].parameterize}.example", password: DEMO_PASSWORD)
    locations = config[:locations].each_with_index.map do |(name, city), index|
      shop.locations.create!(name: name, city: city, address: "#{10 + index * 14} Depot Road, #{city}")
    end
    shop.update!(default_location: locations.first)
    methods = {
      label: shop.shipping_methods.create!(kind: :label, name: "Prepaid label", carrier_name: config[:carrier]),
      own_postage: shop.shipping_methods.create!(kind: :own_postage, name: "Post it yourself"),
    }
    variants = seed_catalog(shop, config, locations)
    customers = NAMES.zip(SURNAMES).map do |first, last|
      shop.customers.create!(name: "#{first} #{last}", email: "#{first}.#{last}@example.com".downcase)
    end
    orders = Array.new(44) { |index| seed_order(shop, customers[index % customers.size], 1001 + index, variants) }

    plan = STATUS_PLAN.flat_map { |status, count| Array.new(count) { |index| [status, index] } }
    plan.zip(orders).each do |(status, index), order|
      seed_return(shop, order, status, index, locations.sample(random: RANDOM), methods)
    end
  end

  def self.seed_catalog(shop, config, locations)
    config[:products].flat_map do |title, price, sizes|
      product = shop.products.create!(title: title)
      sizes.map do |size|
        variant = product.variants.create!(
          sku: "#{title.split.map { |word| word[0] }.join}-#{size}".upcase.delete(" "),
          title: size, price_cents: price, currency: shop.currency,
        )
        locations.each { |location| variant.inventory_levels.create!(location: location, available: RANDOM.rand(0..25)) }
        variant
      end
    end
  end

  def self.seed_order(shop, customer, number, variants)
    order = shop.orders.create!(customer: customer, number: "##{number}", placed_at: RANDOM.rand(20..90).days.ago)
    variants.sample(RANDOM.rand(1..3), random: RANDOM).each do |variant|
      order.line_items.create!(
        variant: variant, quantity: RANDOM.rand(1..2), price_cents: variant.price_cents, currency: shop.currency,
      )
    end
    order
  end

  def self.seed_return(shop, order, status, index, location, methods)
    travel_to(order.placed_at + RANDOM.rand(1..8).days)
    shipping_method = methods[index.even? ? :label : :own_postage]
    ret = shop.return_orders.create!(
      order: order, customer: order.customer, location: location, shipping_method: shipping_method,
    )
    order.line_items.first(2).each { |line| seed_item(ret, line) }

    events = EVENTS.fetch(status)
    events = %i[approve cancel] if status == :cancelled && index.odd?
    events.each do |event|
      travel(RANDOM.rand(2..30).hours)
      ret.public_send(event)
      after_event(ret, event, events)
    end
  end

  def self.seed_item(ret, line)
    siblings = line.variant.product.variants.where.not(id: line.variant_id)
    exchange = siblings.any? && RANDOM.rand < 0.3
    ret.items.create!(
      order_line_item: line, variant: line.variant, quantity: 1,
      reason: ReturnItem.reasons.keys.sample(random: RANDOM),
      resolution: exchange ? :exchange : :refund,
      exchange_variant: exchange ? siblings.to_a.sample(random: RANDOM) : nil,
    )
  end

  def self.after_event(ret, event, events)
    case event
    when :approve
      reserve_exchanges(ret) unless events.include?(:cancel)
      create_label(ret) if ret.label? && !events.include?(:cancel)
    when :mark_in_transit
      ret.shipment ? ret.shipment.picked_up! : create_own_postage_shipment(ret)
      refund(ret) if ret.shop.refund_on_carrier_pickup && ret.label?
    when :cancel
      ret.record_event(:cancelled, cancelled_by: shopper_cancelled?(ret, events) ? :shopper : :merchant)
    when :receive
      ret.shipment.delivered!
    when :resolve
      refund(ret) if ret.refunds.none?
      ret.items.update_all(outcome: ReturnItem.outcomes[:accepted])
      ret.exchanges.each do |exchange|
        exchange.reservations.destroy_all
        exchange.fulfilled!
      end
    end
  end

  def self.shopper_cancelled?(ret, events)
    ret.shop.name == "Harbour & Pine" && events.include?(:approve)
  end

  def self.create_label(ret)
    tracking = "PX#{ret.id.to_s.rjust(8, "0")}"
    ret.create_shipment!(
      status: :label_created, tracking_number: tracking, label_url: "https://carrier.example/labels/#{tracking}.pdf",
    )
    ret.record_event(:shipment_created, tracking_number: tracking)
  end

  def self.create_own_postage_shipment(ret)
    tracking = "OWN#{ret.id.to_s.rjust(8, "0")}"
    ret.create_shipment!(status: :picked_up, tracking_number: tracking)
    ret.record_event(:shipment_created, tracking_number: tracking)
  end

  def self.reserve_exchanges(ret)
    ret.items.exchange.each do |item|
      exchange = ret.exchanges.create!(variant: item.exchange_variant, quantity: item.quantity, return_item: item)
      exchange.reservations.create!(variant: item.exchange_variant, location: ret.location, quantity: item.quantity)
      ret.record_event(:exchange_reserved, variant_id: item.exchange_variant_id, quantity: item.quantity)
    end
  end

  def self.refund(ret)
    cents = ret.items.refund.sum { |item| item.quantity * item.order_line_item.price_cents }
    return if cents.zero?

    ret.refunds.create!(amount_cents: cents, currency: ret.shop.currency)
    ret.record_event(:refunded, amount_cents: cents)
  end

  def self.summary
    Shop.order(:id).each do |shop|
      counts = shop.return_orders.group(:status).count.map { |status, count| "#{status}=#{count}" }.join(" ")
      puts "Seeded #{shop.name}: #{shop.locations.count} locations, #{shop.return_orders.count} returns (#{counts}), login #{shop.users.first.email}"
    end
  end
end

DemoSeeds.run

# Kopi Threads sends returns to StoreBox, Lumen Home buys labels from ParcelDock, and Harbour & Pine has no integration.
module IntegrationSeeds
  def self.run
    store_box(Shop.find_by!(name: "Kopi Threads"))
    parcel_dock(Shop.find_by!(name: "Lumen Home"))
  end

  def self.store_box(shop)
    integration = shop.create_store_box_integration!(api_key: "sb_test_key", status: :active)
    shop.locations.order(:id).zip(%w[wh_rtm wh_lds]).each do |location, warehouse_id|
      integration.location_mappings.create!(location: location, warehouse_id: warehouse_id)
      location.update!(store_box_warehouse: true)
    end
    { "restock" => "resolve", "damaged" => "manual_review", "wrong_item" => "manual_review" }.each do |result, action|
      integration.result_mappings.create!(result: result, action: action, restock: StoreBox::ResultMapping.default_restock(result))
    end

    shop.return_orders.resolved.order(:id).first(2).each { |ret| graded_return(integration, ret, "restock", "resolve") }
    graded_return(integration, shop.return_orders.received.order(:id).first, "damaged", "manual_review")
    failed_send(integration, shop.return_orders.approved.order(:id).first)
  end

  def self.graded_return(integration, ret, result, action)
    sent_at = approved_at(ret)
    remote_id = "sbr_seed_#{ret.id}"
    results = ret.items.map { |item| { "sku" => item.variant.sku, "quantity" => item.quantity, "result" => result } }
    ret.items.each { |item| item.update!(condition: integration.condition_for(result)) }
    ret.create_store_box_return!(
      store_box_integration: integration, remote_id: remote_id, warehouse_id: integration.location_mappings.find_by!(location: ret.location).warehouse_id,
      status: :inspected, results: results, action: action, created_at: sent_at,
    )
    ret.timeline_events.create!(kind: :sent_to_warehouse, data: { warehouse: "StoreBox", remote_id: remote_id }, created_at: sent_at)
    ret.timeline_events.create!(kind: :warehouse_inspected, data: { warehouse: "StoreBox", results: [result], action: action }, created_at: ret.updated_at)
  end

  def self.failed_send(integration, ret)
    error = "StoreBox is temporarily unavailable."
    integration.send_attempts.create!(return_order: ret, error: error, created_at: approved_at(ret))
    ret.timeline_events.create!(kind: :warehouse_send_failed, data: { warehouse: "StoreBox", error: error }, created_at: approved_at(ret))
  end

  def self.approved_at(ret)
    ret.timeline_events.status_changed.find_by!("data->>'to' = 'approved'").created_at + 1.minute
  end

  def self.parcel_dock(shop)
    shop.locations.create!(name: "ParcelDock PD-01", city: "Wolverhampton", parcel_dock_facility: true)
    shop.create_parcel_dock_integration!(api_key: "pd_lumen_demo", status: :enabled)
  end
end

IntegrationSeeds.run

# One Harbour & Pine approved label return whose label request failed, so the retry action has something to show.
module ShippingSeeds
  def self.run
    ret = Shop.find_by!(name: "Harbour & Pine").return_orders.approved.order(:id).detect(&:label?)
    error = "QuickPost is temporarily unavailable. Retry shortly."
    requested_at = IntegrationSeeds.approved_at(ret)
    ret.shipment.update!(status: :label_failed, tracking_number: nil, label_url: nil, label_request_id: "lbl_seed_#{ret.id}", error: error)
    ret.timeline_events.shipment_created.destroy_all
    ret.timeline_events.create!(kind: :label_requested, data: { carrier: "quickpost" }, created_at: requested_at)
    ret.timeline_events.create!(kind: :label_failed, data: { error: error }, created_at: requested_at + 1.minute)
  end
end

ShippingSeeds.run

# Harbour & Pine has retired its Denver location, and moved one approved own-postage return to another location.
module MoveSeeds
  def self.run
    shop = Shop.find_by!(name: "Harbour & Pine")
    shop.locations.find_by!(name: "Denver Returns").update!(archived_at: 3.days.ago)

    ret = shop.return_orders.approved.order(:id).detect { |r| r.own_postage? && r.exchanges.none? }
    from = ret.location
    to = shop.locations.active.where.not(id: from.id).order(:id).first
    ret.update!(location: to)
    ret.timeline_events.create!(kind: :moved, data: { from: from.name, to: to.name }, created_at: IntegrationSeeds.approved_at(ret) + 2.hours)
  end
end

MoveSeeds.run

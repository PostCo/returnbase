ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

require "minitest/mock"

module ReturnFixtures
  # The shipping service answers at once with a pending request. The label arrives later by callback.
  FakeShipping = Struct.new(:error, :requests) do
    def initialize(error = nil)
      super(error, [])
    end

    def request_label(**request)
      raise VendorClient::Error, error if error

      requests << request
      { "id" => "lbl_#{requests.size}", "status" => "pending" }
    end
  end

  # A shop with a T-shirt in S (ordered) and M (stocked), and a submitted return for the S shirt.
  def build_return(kind: :label, resolution: :refund, refund_on_pickup: false, restock: false)
    @shop = Shop.create!(name: "Test Shop", refund_on_carrier_pickup: refund_on_pickup, restock_on_resolve: restock)
    @location = @shop.locations.create!(name: "Hub", city: "Leeds")
    product = @shop.products.create!(title: "Tee")
    @small = product.variants.create!(sku: "TEE-S", title: "S", price_cents: 2000, currency: "USD")
    @medium = product.variants.create!(sku: "TEE-M", title: "M", price_cents: 2000, currency: "USD")
    @medium.inventory_levels.create!(location: @location, available: 2)
    customer = @shop.customers.create!(name: "Ada", email: "ada@example.com")
    order = @shop.orders.create!(customer: customer, number: "#1", placed_at: Time.current)
    order.line_items.create!(variant: @small, quantity: 2, price_cents: 2000, currency: "USD")
    method = @shop.shipping_methods.create!(kind: kind, name: kind.to_s, carrier_name: "QuickPost")
    outcome = ReturnOrders::SubmitService.call(order: order, shipping_method: method, items: [item(resolution)])
    assert outcome.success?, outcome.errors.full_messages.to_sentence
    @return_order = outcome.payload
  end

  def item(resolution = :refund, quantity: 1)
    { sku: "TEE-S", quantity: quantity, reason: "too_small", resolution: resolution.to_s,
      exchange_sku: (resolution == :exchange ? "TEE-M" : nil) }
  end

  def approve_and_request_label(shipping = FakeShipping.new)
    ShippingClient.stub(:new, shipping) { ReturnOrders::ApproveService.call(return_order: @return_order) }
  end

  def label_created(carrier: "quickpost", tracking_number: "QP#{SecureRandom.hex(4)}")
    Shipments::LabelCreatedService.call!(
      shipment: @return_order.reload.shipment, carrier: carrier, tracking_number: tracking_number,
      label_url: "http://carrier.test/labels/#{@return_order.number}",
    )
  end

  # Approves, then plays the shipping service's callback with a created label.
  def approve_with_label(carrier: "quickpost", shipping: FakeShipping.new)
    outcome = approve_and_request_label(shipping)
    label_created(carrier: carrier)
    outcome
  end
end

require "test_helper"

class MerchantReadApiTest < ActionDispatch::IntegrationTest
  setup do
    @shop = Shop.create!(name: "Mine", currency: "USD")
    @other_shop = Shop.create!(name: "Theirs")
    @label = make_return(@shop, "ada@example.com", "#10", :label)
    @own = make_return(@shop, "bo@example.com", "#11", :own_postage)
    @own.approve
    @foreign = make_return(@other_shop, "ada@example.com", "#10", :label)
    @shop.users.create!(email: "owner@mine.example", password: "secret123")
    sign_in
  end

  test "requests without a login get 401" do
    delete "/api/session"
    get "/api/returns"
    assert_response :unauthorized
  end

  test "index lists only the shop's returns and filters by status, shipping and search" do
    get "/api/returns"
    assert_equal [@own.number, @label.number].sort, response.parsed_body["returns"].map { |r| r["number"] }.sort
    assert_equal 2, response.parsed_body["total"]

    get "/api/returns", params: { status: "approved" }
    assert_equal [@own.id], response.parsed_body["returns"].map { |r| r["id"] }

    get "/api/returns", params: { shipping: "label" }
    assert_equal [@label.id], response.parsed_body["returns"].map { |r| r["id"] }

    get "/api/returns", params: { q: "bo@" }
    assert_equal [@own.id], response.parsed_body["returns"].map { |r| r["id"] }
  end

  test "export.csv applies the same filters" do
    get "/api/returns/export.csv", params: { status: "submitted" }
    assert_response :success
    assert_equal "text/csv", response.media_type
    rows = CSV.parse(response.body)
    assert_equal 2, rows.length
    assert_includes rows.last, @label.number
  end

  test "show returns the detail shape with allowed actions" do
    get "/api/returns/#{@label.id}"
    body = response.parsed_body
    assert_equal %w[approve reject edit_items cancel move].sort, body["allowed_actions"].sort
    assert_equal "ada@example.com", body.dig("customer", "email")
    assert_nil body["shipment"]
    assert_kind_of Array, body["available_items"]
    assert_equal "submitted", body["timeline"].first["kind"]
  end

  test "show does not reveal another shop's return" do
    get "/api/returns/#{@foreign.id}"
    assert_response :not_found
  end

  test "locations and shop settings" do
    get "/api/locations"
    assert_equal ["Hub"], response.parsed_body["locations"].map { |l| l["name"] }

    patch "/api/shop", params: { refund_on_carrier_pickup: true }, as: :json
    assert_response :success
    assert_equal true, response.parsed_body["refund_on_carrier_pickup"]
    assert @shop.reload.refund_on_carrier_pickup

    patch "/api/shop", params: { restock_on_resolve: true }, as: :json
    assert_equal true, response.parsed_body["restock_on_resolve"]
    assert @shop.reload.restock_on_resolve
  end

  private

  def sign_in
    post "/api/session", params: { email: "owner@mine.example", password: "secret123" }, as: :json
    assert_response :success
  end

  def make_return(shop, email, order_number, kind)
    customer = shop.customers.find_or_create_by!(email: email) { |c| c.name = email.split("@").first.capitalize }
    shop.return_orders.create!(
      order: shop.orders.create!(customer: customer, number: order_number, placed_at: Time.current),
      customer: customer,
      location: shop.locations.first || shop.locations.create!(name: "Hub"),
      shipping_method: shop.shipping_methods.create!(kind: kind, name: kind.to_s),
    )
  end
end

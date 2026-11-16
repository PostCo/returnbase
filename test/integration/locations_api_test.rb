require "test_helper"

class LocationsApiTest < ActionDispatch::IntegrationTest
  include ReturnFixtures

  setup do
    build_return(kind: :own_postage)
    @depot = @shop.locations.create!(name: "Depot", city: "York")
    @shop.update!(default_location: @location)
    @shop.users.create!(email: "owner@test.example", password: "secret123")
    post "/api/session", params: { email: "owner@test.example", password: "secret123" }, as: :json
  end

  test "a merchant edits a location and the address reaches the posting instructions" do
    patch "/api/locations/#{@location.id}", params: { name: "Hub East", address: "1 Wharf Lane, Leeds" }, as: :json

    assert_response :success
    assert_equal "1 Wharf Lane, Leeds", response.parsed_body["locations"].find { |l| l["id"] == @location.id }["address"]
    assert_includes @return_order.reload.posting_instructions, "Hub East, 1 Wharf Lane, Leeds"

    patch "/api/locations/#{@location.id}", params: { name: "" }, as: :json
    assert_response :unprocessable_entity
  end

  test "the default location cannot be archived until another one is the default" do
    post "/api/locations/#{@location.id}/archive"
    assert_response :unprocessable_entity
    assert_equal ["The default return location cannot be archived"], response.parsed_body["errors"]

    post "/api/locations/#{@depot.id}/make_default"
    assert_response :success
    post "/api/locations/#{@location.id}/archive"
    assert_response :success

    states = response.parsed_body["locations"].to_h { |l| [l["name"], l.slice("archived", "default")] }
    assert_equal({ "Hub" => { "archived" => true, "default" => false }, "Depot" => { "archived" => false, "default" => true } }, states)
  end

  test "an archived location cannot become the default and can be restored" do
    post "/api/locations/#{@depot.id}/archive"
    post "/api/locations/#{@depot.id}/make_default"
    assert_response :unprocessable_entity

    post "/api/locations/#{@depot.id}/unarchive"
    assert_response :success
    assert_equal false, response.parsed_body["locations"].find { |l| l["id"] == @depot.id }["archived"]
  end

  test "a new shopper return goes to the default location" do
    post "/api/locations/#{@depot.id}/make_default"
    order = @shop.reload.orders.first
    order.line_items.create!(variant: @medium, quantity: 1, price_cents: 2000, currency: "USD")

    outcome = ReturnOrders::SubmitService.call(
      order: order, shipping_method: @return_order.shipping_method, items: [item.merge(sku: "TEE-M", exchange_sku: nil)],
    )

    assert_equal @depot, outcome.payload.location
  end

  test "a merchant moves a return from its page" do
    get "/api/returns/#{@return_order.id}"
    assert_includes response.parsed_body["allowed_actions"], "move"

    post "/api/returns/#{@return_order.id}/move", params: { location_id: @depot.id }, as: :json

    assert_response :success
    assert_equal "Depot", response.parsed_body["location"]["name"]
    assert_equal "moved", response.parsed_body["timeline"].last["kind"]

    post "/api/returns/#{@return_order.id}/move", params: { location_id: @depot.id }, as: :json
    assert_response :unprocessable_entity
  end
end

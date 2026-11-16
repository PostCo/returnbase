require_relative "test_helper"

class ParcelDockTest < VendorTest
  KEY = { "HTTP_X_API_KEY" => "pd_any_key" }.freeze
  SHIPMENT = { reference: "RET-1", recipient: { name: "Sam Shopper" } }.freeze

  def app = ParcelDock

  def test_create_shipment_returns_label_and_tracking_number
    post_json "/shipments", SHIPMENT, KEY
    assert_equal 201, last_response.status
    assert_equal "PD00000001", body["tracking_number"]
    assert_match %r{/parceldock/labels/PD00000001\z}, body["label_url"]
    assert_equal "PD-01", body["facility"]
  end

  def test_label_page_is_public
    post_json "/shipments", SHIPMENT, KEY
    get "/labels/PD00000001"
    assert_equal 200, last_response.status
    assert_includes last_response.body, "Sam Shopper"
  end

  def test_requires_a_key
    post_json "/shipments", SHIPMENT
    assert_equal 401, last_response.status
  end

  def test_validates_the_payload
    post_json "/shipments", { reference: "RET-1" }, KEY
    assert_equal 422, last_response.status
  end

  def test_temporary_failure_scenario
    post "/admin/scenario", scenario: "temporary_failure"
    post_json "/shipments", SHIPMENT, KEY
    assert_equal 503, last_response.status
  end

  def test_tracking_follows_the_console
    post_json "/shipments", SHIPMENT, KEY
    get "/tracking/PD00000001", {}, KEY
    assert_equal "label_created", body["status"]

    post "/console/parcels/PD00000001/picked_up"
    post "/console/parcels/PD00000001/delivered"
    get "/tracking/PD00000001", {}, KEY
    assert_equal "delivered", body["status"]
    assert_equal %w[label_created picked_up delivered], body["events"].map { |e| e["status"] }
  end

  def test_tracking_unknown_number_is_404
    get "/tracking/PD404", {}, KEY
    assert_equal 404, last_response.status
  end

  def test_delivered_before_pickup_is_ignored
    post_json "/shipments", SHIPMENT, KEY
    post "/console/parcels/PD00000001/delivered"
    get "/tracking/PD00000001", {}, KEY
    assert_equal "label_created", body["status"]
  end
end

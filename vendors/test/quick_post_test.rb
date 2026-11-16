require_relative "test_helper"

class QuickPostTest < VendorTest
  KEY = { "HTTP_AUTHORIZATION" => "Bearer qp_any_key" }.freeze
  LABEL = { reference: "RET-1", to: { name: "Sam Shopper" } }.freeze

  def app = QuickPost

  def setup
    super
    @sent = []
    @original = QuickPost.webhook_sender
    QuickPost.webhook_sender = ->(url, payload) { @sent << [url, payload]; { status: 200 } }
  end

  def teardown = QuickPost.webhook_sender = @original

  def test_create_label_returns_label_and_tracking_number
    post_json "/labels", LABEL, KEY
    assert_equal 201, last_response.status
    assert_equal "QP00000001", body["tracking_number"]
    assert_match %r{/quickpost/labels/QP00000001\z}, body["label_url"]
  end

  def test_requires_a_bearer_token
    post_json "/labels", LABEL
    assert_equal 401, last_response.status
  end

  def test_validates_the_payload
    post_json "/labels", { reference: "RET-1" }, KEY
    assert_equal 422, last_response.status
  end

  def test_temporary_failure_scenario
    post "/admin/scenario", scenario: "temporary_failure"
    post_json "/labels", LABEL, KEY
    assert_equal 503, last_response.status
  end

  def test_tracking_reports_status
    post_json "/labels", LABEL, KEY
    get "/tracking/QP00000001", {}, KEY
    assert_equal "label_created", body["status"]
    get "/tracking/QP404", {}, KEY
    assert_equal 404, last_response.status
  end

  def test_pickup_and_delivery_call_the_webhook_and_log_it
    post_json "/labels", LABEL, KEY
    post "/console/parcels/QP00000001/picked_up"
    post "/console/parcels/QP00000001/delivered"

    assert_equal ["parcel.picked_up", "parcel.delivered"], @sent.map { |_, p| p[:event] }
    url, payload = @sent.first
    assert_equal "http://api:3100/webhooks/quickpost", url
    assert_equal ["QP00000001", "RET-1", "picked_up"], payload.values_at(:tracking_number, :reference, :status)

    get "/log.json"
    out = body["requests"].select { |e| e["direction"] == "out" }
    assert_equal [200, 200], out.map { |e| e["status"] }
  end

  def test_repeating_a_transition_does_not_resend
    post_json "/labels", LABEL, KEY
    2.times { post "/console/parcels/QP00000001/picked_up" }
    assert_equal 1, @sent.size
  end

  def test_unreachable_webhook_is_logged_not_raised
    QuickPost.webhook_sender = ->(_url, _payload) { { error: "connection refused" } }
    post_json "/labels", LABEL, KEY
    post "/console/parcels/QP00000001/picked_up"
    get "/log.json"
    assert_equal "error: connection refused", body["requests"].last["status"]
  end
end

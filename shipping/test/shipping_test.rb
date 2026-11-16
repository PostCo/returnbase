ENV["RACK_ENV"] = "test"
require "minitest/autorun"
require "minitest/mock"
require "rack/test"
require_relative "../app"

class ShippingTest < Minitest::Test
  include Rack::Test::Methods

  CALLBACK = "http://returnbase.test/webhooks/shipping".freeze
  REQUEST = { reference: "R1001", carrier: "quickpost", recipient_name: "Ada", callback_url: CALLBACK }.freeze

  def app = Shipping

  def setup
    Shipping.store.reset
    Shipping.set :background, false
    @calls = []
  end

  def post_label(body = REQUEST)
    post "/labels", body.to_json, "CONTENT_TYPE" => "application/json"
  end

  def body = JSON.parse(last_response.body)

  def fake_post(carrier_status, carrier_body)
    lambda do |url, payload, headers = {}|
      @calls << [url, payload, headers]
      url == CALLBACK ? [200, {}] : [carrier_status, carrier_body]
    end
  end

  def test_answers_202_and_calls_back_with_the_created_label
    Http.stub(:post_json, fake_post(201, { "tracking_number" => "QP1", "label_url" => "http://x/QP1" })) { post_label }

    assert_equal 202, last_response.status
    assert_equal ["lbl_1", "pending"], body.values_at("id", "status")

    callback_url, payload, headers = @calls.last
    assert_equal CALLBACK, callback_url
    assert_equal({ id: "lbl_1", reference: "R1001", status: "created", carrier: "quickpost", tracking_number: "QP1", label_url: "http://x/QP1" }, payload)
    assert_equal LabelJob::CALLBACK_TOKEN, headers["X-Shipping-Token"]

    get "/labels/lbl_1"
    assert_equal "created", body["status"]
  end

  def test_carrier_failure_scenario_calls_back_with_a_failed_label
    post "/admin/scenario", scenario: "carrier_failure"
    Http.stub(:post_json, fake_post(201, {})) { post_label }

    assert_equal ["failed", "The carrier rejected the label request."], @calls.last[1].values_at(:status, :error)
  end

  def test_a_carrier_error_becomes_a_failed_label
    error = { "error" => { "message" => "ParcelDock is temporarily unavailable." } }
    Http.stub(:post_json, fake_post(503, error)) { post_label(REQUEST.merge(carrier: "parceldock", carrier_api_key: "pd")) }

    assert_equal ["failed", "ParcelDock is temporarily unavailable."], @calls.last[1].values_at(:status, :error)
  end

  def test_validates_the_request
    post_label(REQUEST.merge(carrier: "parceldock"))
    assert_equal 422, last_response.status

    post_label(REQUEST.merge(carrier: "unsupported_carrier"))
    assert_equal 422, last_response.status
  end
end

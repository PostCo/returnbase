require_relative "http"
require_relative "labels"

# Creates one requested label at the carrier, then tells the requester with a signed callback.
class LabelJob
  CALLBACK_TOKEN = ENV.fetch("SHIPPING_CALLBACK_TOKEN", "dev-shipping-token")
  VENDORS_URL = ENV.fetch("VENDORS_URL", "http://vendors:4100")
  QUICKPOST_KEY = ENV.fetch("QUICKPOST_API_KEY", "shipping-sandbox")

  def initialize(store, id)
    @store = store
    @id = id
  end

  def run
    label = @store.find(@id)
    @store.update(@id, create_at_carrier(label))
    send_callback(@store.find(@id))
  end

  private

  def create_at_carrier(label)
    return failed("The carrier rejected the label request.") if @store.scenario == "carrier_failure"

    url, body, headers = request_for(label)
    status, response = Http.post_json(url, body, headers)
    @store.record(direction: "out", method: "POST", url:, body: response.to_json, status:)
    return failed(response.dig("error", "message") || "The carrier answered HTTP #{status}.") unless status == 201

    { status: "created", tracking_number: response["tracking_number"], label_url: response["label_url"] }
  end

  def request_for(label)
    if label[:carrier] == "quickpost"
      ["#{VENDORS_URL}/quickpost/labels", { reference: label[:reference], to: { name: label[:recipient_name] } },
       { "Authorization" => "Bearer #{QUICKPOST_KEY}" }]
    else
      ["#{VENDORS_URL}/parceldock/shipments", { reference: label[:reference], recipient: { name: label[:recipient_name] } },
       { "X-Api-Key" => label[:carrier_api_key].to_s }]
    end
  end

  def failed(error) = { status: "failed", error: }

  def send_callback(label)
    body = Labels.present(label)
    status, = Http.post_json(label[:callback_url], body, { "X-Shipping-Token" => CALLBACK_TOKEN })
    @store.record(direction: "out", method: "POST", url: label[:callback_url], body: body.to_json, status:)
  end
end

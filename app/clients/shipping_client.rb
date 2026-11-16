# The shipping team's label service. API reference: shipping/docs/api.md
class ShippingClient < VendorClient
  def initialize(base_url: ENV.fetch("SHIPPING_URL", "http://shipping:4300"))
    super(base_url: base_url, headers: {})
  end

  # Answers at once with {"id", "status" => "pending"}. The label itself arrives later, on callback_url.
  def request_label(reference:, carrier:, recipient_name:, callback_url:, carrier_api_key: nil)
    post("/labels", reference: reference, carrier: carrier, carrier_api_key: carrier_api_key,
                    recipient_name: recipient_name, callback_url: callback_url)
  end
end

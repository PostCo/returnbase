# ParcelDock label provider. API reference: vendors/docs/parceldock.md
class ParcelDockClient < VendorClient
  def initialize(api_key:, base_url: ENV.fetch("PARCELDOCK_URL", "http://vendors:4100/parceldock"))
    super(base_url: base_url, headers: { "X-Api-Key" => api_key.to_s })
  end

  def create_label(reference:, recipient_name:)
    post("/shipments", reference: reference, recipient: { name: recipient_name })
  end
end

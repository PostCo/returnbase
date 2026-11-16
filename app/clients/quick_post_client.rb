# QuickPost label carrier. API reference: vendors/docs/quickpost.md
class QuickPostClient < VendorClient
  def initialize(base_url: ENV.fetch("QUICKPOST_URL", "http://vendors:4100/quickpost"),
                 api_key: ENV.fetch("QUICKPOST_API_KEY", "returnbase-sandbox"))
    super(base_url: base_url, headers: { "Authorization" => "Bearer #{api_key}" })
  end

  def create_label(reference:, recipient_name:)
    post("/labels", reference: reference, to: { name: recipient_name })
  end
end

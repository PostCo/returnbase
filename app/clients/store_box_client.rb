# StoreBox warehouse API. API reference: vendors/docs/storebox.md
class StoreBoxClient < VendorClient
  def initialize(api_key:, base_url: ENV.fetch("STOREBOX_URL", "http://vendors:4100/storebox"))
    super(base_url: base_url, headers: { "X-Api-Key" => api_key.to_s })
  end

  def account
    get("/account")
  end

  def warehouses
    get("/warehouses").fetch("warehouses")
  end

  def create_return(reference:, warehouse_id:, items:)
    post("/returns", reference: reference, warehouse_id: warehouse_id, items: items)
  end

  def find_return(id)
    get("/returns/#{id}")
  end
end

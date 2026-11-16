# Asks StoreBox whether an API key works. Connecting, replacing the key and activating all check it first.
module StoreBoxIntegration::CredentialCheck
  private

  def check_credentials(api_key)
    StoreBoxClient.new(api_key: api_key).account
  rescue VendorClient::Error => e
    errors.add(:base, e.status == 401 ? "StoreBox did not accept this API key" : "Could not reach StoreBox: #{e.message}")
  end
end

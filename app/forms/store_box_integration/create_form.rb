# Connects StoreBox for a shop. The integration starts connected, so nothing is sent until the merchant activates it.
class StoreBoxIntegration::CreateForm
  include ActiveModel::Validations
  include StoreBoxIntegration::CredentialCheck

  attr_reader :integration

  validates :api_key, presence: true
  validate :not_connected_yet
  validate { check_credentials(api_key) if api_key.present? && errors.empty? }

  def initialize(shop, params)
    @shop = shop
    @api_key = params[:api_key]
  end

  def submit
    return false if invalid?

    @integration = shop.create_store_box_integration!(api_key: api_key, status: :connected)
    true
  end

  private

  attr_reader :shop, :api_key

  def not_connected_yet
    errors.add(:base, "StoreBox is already connected") if shop.store_box_integration
  end
end

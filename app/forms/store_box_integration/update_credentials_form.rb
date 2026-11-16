# Replaces the API key. The status stays as it is, so an active integration stays active with the new key.
class StoreBoxIntegration::UpdateCredentialsForm
  include ActiveModel::Validations
  include StoreBoxIntegration::CredentialCheck

  validates :api_key, presence: true
  validate { check_credentials(api_key) if api_key.present? }

  def initialize(integration, params)
    @integration = integration
    @api_key = params[:api_key]
  end

  def submit
    return false if invalid?

    integration.update!(api_key: api_key)
    true
  end

  private

  attr_reader :integration, :api_key
end

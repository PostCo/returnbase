# The merchant's decision to switch StoreBox on. From here, newly approved returns at mapped locations go to StoreBox.
# Activating sends nothing by itself.
class StoreBoxIntegration::ActivateForm
  include ActiveModel::Validations
  include StoreBoxIntegration::CredentialCheck

  validate :setup_complete
  validate { check_credentials(integration.api_key) if errors.empty? }

  def initialize(integration)
    @integration = integration
  end

  def submit
    return false if invalid?

    integration.active!
    true
  end

  private

  attr_reader :integration

  def setup_complete
    StoreBoxIntegration::ReadinessService.new(integration).call.missing.each { |check| errors.add(:base, "Not ready: #{check.label}") }
  end
end

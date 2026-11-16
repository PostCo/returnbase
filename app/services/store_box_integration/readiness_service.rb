# Says whether StoreBox's setup is complete enough to activate. Being ready does not activate it (ActivateForm does).
class StoreBoxIntegration::ReadinessService
  Check = Data.define(:key, :label, :done)

  attr_reader :checks

  def initialize(integration)
    @integration = integration
  end

  def call
    mapped_results = integration.result_mappings.pluck(:result)
    @checks = [
      Check.new(:credentials, "StoreBox accepted the API key", integration.persisted?),
      Check.new(:warehouse, "At least one return location sends to a StoreBox warehouse", integration.shop.locations.store_box_warehouse.exists?),
      Check.new(:results, "Every inspection result has an action", (StoreBox::ResultMapping::RESULTS - mapped_results).empty?),
    ]
    self
  end

  def ready?
    missing.empty?
  end

  def missing
    checks.reject(&:done)
  end

  private

  attr_reader :integration
end

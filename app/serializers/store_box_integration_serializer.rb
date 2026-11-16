class StoreBoxIntegrationSerializer
  def initialize(integration)
    @integration = integration
  end

  def as_json(*)
    readiness = StoreBoxIntegration::ReadinessService.new(integration).call
    warehouses = integration.location_mappings.to_h { |mapping| [mapping.location_id, mapping.warehouse_id] }
    mappings = integration.result_mappings.index_by(&:result)
    {
      id: integration.id,
      status: integration.status,
      api_key_hint: integration.api_key_hint,
      readiness: { ready: readiness.ready?, checks: readiness.checks.map(&:to_h) },
      location_mappings: integration.shop.locations.order(:name).map do |location|
        { location_id: location.id, name: location.name, city: location.city, warehouse_id: warehouses[location.id] }
      end,
      result_mappings: StoreBox::ResultMapping::RESULTS.map do |result|
        mapping = mappings[result]
        { result: result, action: mapping&.action, restock: mapping ? mapping.restock? : StoreBox::ResultMapping.default_restock(result) }
      end,
      open_returns: integration.returns.open.count,
    }
  end

  private

  attr_reader :integration
end

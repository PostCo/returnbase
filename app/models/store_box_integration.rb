# StoreBox, a self-serve warehouse (WMS). The merchant connects it, maps locations and inspection results, then
# activates it. Saving settings never activates it (StoreBoxIntegration::ReadinessService).
class StoreBoxIntegration < Integration
  enum :status, { connected: 10, active: 20, disabled: 30 }

  has_many :location_mappings, class_name: "StoreBox::LocationMapping", dependent: :destroy, inverse_of: :store_box_integration
  has_many :result_mappings, class_name: "StoreBox::ResultMapping", dependent: :destroy, inverse_of: :store_box_integration
  has_many :returns, class_name: "StoreBox::Return", dependent: :destroy, inverse_of: :store_box_integration
  has_many :send_attempts, class_name: "StoreBox::SendAttempt", dependent: :destroy, inverse_of: :store_box_integration

  def client
    StoreBoxClient.new(api_key: api_key)
  end

  def condition_for(result)
    result_mappings.find { |mapping| mapping.result == result }&.restock? ? :restockable : :not_restockable
  end

  # A return gets one action for all its items: the most cautious one any item's result maps to.
  def action_for(results)
    actions = results.map { |result| result_mappings.find { |mapping| mapping.result == result }&.action || "manual_review" }
    actions.max_by { |action| StoreBox::ResultMapping::ACTIONS.index(action) }
  end
end

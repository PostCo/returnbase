# Saves the location and result mappings. Saving never changes the status: only ActivateForm switches StoreBox on.
# While StoreBox is active, the merchant cannot save away the last mapped location or leave a result without an action.
class StoreBoxIntegration::UpdateForm
  include ActiveModel::Validations

  validate :locations_belong_to_shop
  validate :results_and_actions_known
  validate :still_complete_while_active
  validate :warehouses_known

  # location_mappings: [{ location_id:, warehouse_id: }], a blank warehouse_id stops sending that location's returns.
  # result_mappings: [{ result:, action:, restock: }], a blank action clears the mapping.
  def initialize(integration, params)
    @integration = integration
    @location_mappings = params[:location_mappings] || []
    @result_mappings = params[:result_mappings] || []
  end

  def submit
    return false if invalid?

    StoreBoxIntegration.transaction do
      location_mappings.each { |mapping| save_location_mapping(mapping) }
      result_mappings.each { |mapping| save_result_mapping(mapping) }
    end
    true
  end

  private

  attr_reader :integration, :location_mappings, :result_mappings

  def save_location_mapping(mapping)
    location = integration.shop.locations.find(mapping[:location_id])
    existing = integration.location_mappings.find_by(location: location)
    if mapping[:warehouse_id].present?
      (existing || integration.location_mappings.build(location: location)).update!(warehouse_id: mapping[:warehouse_id])
    else
      existing&.destroy!
    end
    location.update!(store_box_warehouse: mapping[:warehouse_id].present?)
  end

  def save_result_mapping(mapping)
    existing = integration.result_mappings.find_or_initialize_by(result: mapping[:result])
    restock = mapping.fetch(:restock) { StoreBox::ResultMapping.default_restock(mapping[:result]) }
    mapping[:action].present? ? existing.update!(action: mapping[:action], restock: restock) : (existing.destroy! if existing.persisted?)
  end

  def locations_belong_to_shop
    ids = location_mappings.map { |mapping| mapping[:location_id].to_i }.uniq
    errors.add(:base, "Unknown return location") if integration.shop.locations.where(id: ids).count != ids.size
  end

  def results_and_actions_known
    unknown = result_mappings.reject do |mapping|
      StoreBox::ResultMapping::RESULTS.include?(mapping[:result]) &&
        (mapping[:action].blank? || StoreBox::ResultMapping::ACTIONS.include?(mapping[:action]))
    end
    errors.add(:base, "Unknown inspection result or action") if unknown.any?
  end

  def still_complete_while_active
    return unless integration.active?

    if location_mappings.any? && location_mappings.none? { |mapping| mapping[:warehouse_id].present? }
      errors.add(:base, "StoreBox is active, so at least one location must send to a StoreBox warehouse. Deactivate StoreBox first.")
    end
    if result_mappings.any? { |mapping| mapping[:action].blank? }
      errors.add(:base, "StoreBox is active, so every inspection result needs an action. Deactivate StoreBox first.")
    end
  end

  def warehouses_known
    chosen = location_mappings.filter_map { |mapping| mapping[:warehouse_id].presence }.uniq
    return if chosen.empty?

    known = integration.client.warehouses.map { |warehouse| warehouse["id"] }
    errors.add(:base, "Unknown StoreBox warehouse: #{(chosen - known).join(", ")}") if (chosen - known).any?
  rescue VendorClient::Error => e
    errors.add(:base, "Could not load StoreBox warehouses: #{e.message}")
  end
end

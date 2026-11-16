# What Returnbase does when StoreBox inspects a return and grades an item with this result.
class StoreBox::ResultMapping < ApplicationRecord
  RESULTS = %w[restock damaged wrong_item].freeze
  # Least cautious first. StoreBoxIntegration#action_for picks the last one any item maps to.
  ACTIONS = %w[resolve manual_review].freeze

  belongs_to :store_box_integration

  def self.default_restock(result)
    result == "restock"
  end

  validates :result, inclusion: { in: RESULTS }, uniqueness: { scope: :store_box_integration_id }
  validates :action, inclusion: { in: ACTIONS }
end

# One row per vendor a shop has connected. Each vendor is a subclass with its own status enum.
class Integration < ApplicationRecord
  belongs_to :shop

  store :credentials, accessors: [:api_key], coder: JSON
  encrypts :credentials

  validates :api_key, presence: true
  validates :type, uniqueness: { scope: :shop_id }

  def api_key_hint
    "••••#{api_key.to_s.last(4)}"
  end
end

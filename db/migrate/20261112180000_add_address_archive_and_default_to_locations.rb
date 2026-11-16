class AddAddressArchiveAndDefaultToLocations < ActiveRecord::Migration[7.2]
  def change
    add_column :locations, :address, :string
    add_column :locations, :archived_at, :datetime
    add_column :shops, :default_location_id, :bigint

    reversible do |direction|
      direction.up do
        execute <<~SQL
          UPDATE shops SET default_location_id = (SELECT MIN(id) FROM locations WHERE locations.shop_id = shops.id)
        SQL
      end
    end
  end
end

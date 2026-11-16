class AddRestockOnResolve < ActiveRecord::Migration[7.2]
  def change
    add_column :shops, :restock_on_resolve, :boolean, null: false, default: false
    add_column :return_items, :condition, :integer
    add_column :store_box_result_mappings, :restock, :boolean, null: false, default: false

    reversible do |direction|
      direction.up { execute "UPDATE store_box_result_mappings SET restock = TRUE WHERE result = 'restock'" }
    end
  end
end

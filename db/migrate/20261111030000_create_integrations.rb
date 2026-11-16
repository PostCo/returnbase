class CreateIntegrations < ActiveRecord::Migration[7.2]
  def change
    create_table :integrations do |t|
      t.references :shop, null: false, foreign_key: true
      t.string :type, null: false
      t.integer :status, null: false
      t.text :credentials
      t.jsonb :data, null: false, default: {}
      t.timestamps
    end
    add_index :integrations, %i[shop_id type], unique: true

    create_table :store_box_location_mappings do |t|
      t.references :store_box_integration, null: false, foreign_key: { to_table: :integrations }
      t.references :location, null: false, foreign_key: true, index: { unique: true }
      t.string :warehouse_id, null: false
      t.timestamps
    end

    create_table :store_box_result_mappings do |t|
      t.references :store_box_integration, null: false, foreign_key: { to_table: :integrations }
      t.string :result, null: false
      t.string :action, null: false
      t.timestamps
    end
    add_index :store_box_result_mappings, %i[store_box_integration_id result], unique: true

    create_table :store_box_returns do |t|
      t.references :store_box_integration, null: false, foreign_key: { to_table: :integrations }
      t.references :return_order, null: false, foreign_key: true, index: { unique: true }
      t.string :remote_id, null: false
      t.string :warehouse_id, null: false
      t.integer :status, null: false, default: 0
      t.jsonb :results, null: false, default: []
      t.string :action
      t.timestamps
    end

    create_table :store_box_send_attempts do |t|
      t.references :store_box_integration, null: false, foreign_key: { to_table: :integrations }
      t.references :return_order, null: false, foreign_key: true
      t.text :error, null: false
      t.datetime :created_at, null: false
    end
  end
end

class CreateDomainTables < ActiveRecord::Migration[7.2]
  def change
    create_table :shops do |t|
      t.string :name, null: false
      t.string :currency, null: false, default: "USD"
      t.boolean :refund_on_carrier_pickup, null: false, default: false
      t.timestamps
    end

    create_table :locations do |t|
      t.references :shop, null: false, foreign_key: true
      t.string :name, null: false
      t.string :city
      t.integer :flags, null: false, default: 0
      t.timestamps
    end

    create_table :customers do |t|
      t.references :shop, null: false, foreign_key: true
      t.string :name, null: false
      t.string :email, null: false
      t.timestamps
    end

    create_table :products do |t|
      t.references :shop, null: false, foreign_key: true
      t.string :title, null: false
      t.timestamps
    end

    create_table :variants do |t|
      t.references :product, null: false, foreign_key: true
      t.string :sku, null: false
      t.string :title, null: false
      t.integer :price_cents, null: false
      t.string :currency, null: false
      t.timestamps
    end

    create_table :inventory_levels do |t|
      t.references :variant, null: false, foreign_key: true
      t.references :location, null: false, foreign_key: true
      t.integer :available, null: false, default: 0
      t.timestamps
    end
    add_index :inventory_levels, [:variant_id, :location_id], unique: true

    create_table :orders do |t|
      t.references :shop, null: false, foreign_key: true
      t.references :customer, null: false, foreign_key: true
      t.string :number, null: false
      t.datetime :placed_at, null: false
      t.timestamps
    end

    create_table :order_line_items do |t|
      t.references :order, null: false, foreign_key: true
      t.references :variant, null: false, foreign_key: true
      t.integer :quantity, null: false
      t.integer :price_cents, null: false
      t.string :currency, null: false
      t.timestamps
    end

    create_table :shipping_methods do |t|
      t.references :shop, null: false, foreign_key: true
      t.integer :kind, null: false
      t.string :name, null: false
      t.string :carrier_name
      t.timestamps
    end

    create_table :return_orders do |t|
      t.references :shop, null: false, foreign_key: true
      t.references :order, null: false, foreign_key: true
      t.references :customer, null: false, foreign_key: true
      t.references :location, null: false, foreign_key: true
      t.references :shipping_method, null: false, foreign_key: true
      t.string :number, null: false
      t.integer :status, null: false, default: 0
      t.timestamps
    end
    add_index :return_orders, [:shop_id, :number], unique: true
    add_index :return_orders, [:shop_id, :status]

    create_table :return_items do |t|
      t.references :return_order, null: false, foreign_key: true
      t.references :order_line_item, null: false, foreign_key: true
      t.references :variant, null: false, foreign_key: true
      t.references :exchange_variant, foreign_key: { to_table: :variants }
      t.integer :quantity, null: false
      t.integer :reason, null: false
      t.integer :resolution, null: false
      t.timestamps
    end

    create_table :exchanges do |t|
      t.references :return_order, null: false, foreign_key: true
      t.references :variant, null: false, foreign_key: true
      t.integer :quantity, null: false
      t.timestamps
    end

    create_table :reservations do |t|
      t.references :exchange, null: false, foreign_key: true
      t.references :variant, null: false, foreign_key: true
      t.references :location, null: false, foreign_key: true
      t.integer :quantity, null: false
      t.timestamps
    end

    create_table :refunds do |t|
      t.references :return_order, null: false, foreign_key: true
      t.integer :amount_cents, null: false
      t.string :currency, null: false
      t.timestamps
    end

    create_table :shipments do |t|
      t.references :return_order, null: false, foreign_key: true
      t.string :label_url
      t.string :tracking_number
      t.integer :status, null: false, default: 0
      t.timestamps
    end

    create_table :timeline_events do |t|
      t.references :return_order, null: false, foreign_key: true
      t.integer :kind, null: false
      t.jsonb :data, null: false, default: {}
      t.datetime :created_at, null: false
    end
  end
end

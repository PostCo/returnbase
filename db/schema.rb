# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.2].define(version: 2026_11_16_100000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "customers", force: :cascade do |t|
    t.bigint "shop_id", null: false
    t.string "name", null: false
    t.string "email", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["shop_id"], name: "index_customers_on_shop_id"
  end

  create_table "exchanges", force: :cascade do |t|
    t.bigint "return_order_id", null: false
    t.bigint "variant_id", null: false
    t.integer "quantity", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "status", default: 0, null: false
    t.bigint "return_item_id"
    t.index ["return_item_id"], name: "index_exchanges_on_return_item_id"
    t.index ["return_order_id"], name: "index_exchanges_on_return_order_id"
    t.index ["variant_id"], name: "index_exchanges_on_variant_id"
  end

  create_table "integrations", force: :cascade do |t|
    t.bigint "shop_id", null: false
    t.string "type", null: false
    t.integer "status", null: false
    t.text "credentials"
    t.jsonb "data", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["shop_id", "type"], name: "index_integrations_on_shop_id_and_type", unique: true
    t.index ["shop_id"], name: "index_integrations_on_shop_id"
  end

  create_table "inventory_levels", force: :cascade do |t|
    t.bigint "variant_id", null: false
    t.bigint "location_id", null: false
    t.integer "available", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["location_id"], name: "index_inventory_levels_on_location_id"
    t.index ["variant_id", "location_id"], name: "index_inventory_levels_on_variant_id_and_location_id", unique: true
    t.index ["variant_id"], name: "index_inventory_levels_on_variant_id"
  end

  create_table "locations", force: :cascade do |t|
    t.bigint "shop_id", null: false
    t.string "name", null: false
    t.string "city"
    t.integer "flags", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "address"
    t.datetime "archived_at"
    t.index ["shop_id"], name: "index_locations_on_shop_id"
  end

  create_table "order_line_items", force: :cascade do |t|
    t.bigint "order_id", null: false
    t.bigint "variant_id", null: false
    t.integer "quantity", null: false
    t.integer "price_cents", null: false
    t.string "currency", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["order_id"], name: "index_order_line_items_on_order_id"
    t.index ["variant_id"], name: "index_order_line_items_on_variant_id"
  end

  create_table "orders", force: :cascade do |t|
    t.bigint "shop_id", null: false
    t.bigint "customer_id", null: false
    t.string "number", null: false
    t.datetime "placed_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["customer_id"], name: "index_orders_on_customer_id"
    t.index ["shop_id"], name: "index_orders_on_shop_id"
  end

  create_table "products", force: :cascade do |t|
    t.bigint "shop_id", null: false
    t.string "title", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["shop_id"], name: "index_products_on_shop_id"
  end

  create_table "refunds", force: :cascade do |t|
    t.bigint "return_order_id", null: false
    t.integer "amount_cents", null: false
    t.string "currency", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["return_order_id"], name: "index_refunds_on_return_order_id"
  end

  create_table "reservations", force: :cascade do |t|
    t.bigint "exchange_id", null: false
    t.bigint "variant_id", null: false
    t.bigint "location_id", null: false
    t.integer "quantity", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["exchange_id"], name: "index_reservations_on_exchange_id"
    t.index ["location_id"], name: "index_reservations_on_location_id"
    t.index ["variant_id"], name: "index_reservations_on_variant_id"
  end

  create_table "return_items", force: :cascade do |t|
    t.bigint "return_order_id", null: false
    t.bigint "order_line_item_id", null: false
    t.bigint "variant_id", null: false
    t.bigint "exchange_variant_id"
    t.integer "quantity", null: false
    t.integer "reason", null: false
    t.integer "resolution", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "condition"
    t.integer "outcome"
    t.boolean "restock"
    t.index ["exchange_variant_id"], name: "index_return_items_on_exchange_variant_id"
    t.index ["order_line_item_id"], name: "index_return_items_on_order_line_item_id"
    t.index ["return_order_id"], name: "index_return_items_on_return_order_id"
    t.index ["variant_id"], name: "index_return_items_on_variant_id"
  end

  create_table "return_orders", force: :cascade do |t|
    t.bigint "shop_id", null: false
    t.bigint "order_id", null: false
    t.bigint "customer_id", null: false
    t.bigint "location_id", null: false
    t.bigint "shipping_method_id", null: false
    t.string "number", null: false
    t.integer "status", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["customer_id"], name: "index_return_orders_on_customer_id"
    t.index ["location_id"], name: "index_return_orders_on_location_id"
    t.index ["order_id"], name: "index_return_orders_on_order_id"
    t.index ["shipping_method_id"], name: "index_return_orders_on_shipping_method_id"
    t.index ["shop_id", "number"], name: "index_return_orders_on_shop_id_and_number", unique: true
    t.index ["shop_id", "status"], name: "index_return_orders_on_shop_id_and_status"
    t.index ["shop_id"], name: "index_return_orders_on_shop_id"
  end

  create_table "shipments", force: :cascade do |t|
    t.bigint "return_order_id", null: false
    t.string "label_url"
    t.string "tracking_number"
    t.integer "status", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "label_request_id"
    t.string "error"
    t.index ["label_request_id"], name: "index_shipments_on_label_request_id"
    t.index ["return_order_id"], name: "index_shipments_on_return_order_id"
  end

  create_table "shipping_methods", force: :cascade do |t|
    t.bigint "shop_id", null: false
    t.integer "kind", null: false
    t.string "name", null: false
    t.string "carrier_name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["shop_id"], name: "index_shipping_methods_on_shop_id"
  end

  create_table "shops", force: :cascade do |t|
    t.string "name", null: false
    t.string "currency", default: "USD", null: false
    t.boolean "refund_on_carrier_pickup", default: false, null: false
    t.boolean "restock_on_resolve", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "default_location_id"
  end

  create_table "solid_queue_batch_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.bigint "batch_id", null: false
    t.datetime "created_at", null: false
    t.index ["batch_id"], name: "index_solid_queue_batch_executions_on_batch_id"
    t.index ["job_id"], name: "index_solid_queue_batch_executions_on_job_id", unique: true
  end

  create_table "solid_queue_batches", force: :cascade do |t|
    t.string "active_job_batch_id"
    t.string "description"
    t.text "on_finish"
    t.text "on_success"
    t.text "on_failure"
    t.text "metadata"
    t.integer "total_jobs", default: 0, null: false
    t.integer "completed_jobs", default: 0, null: false
    t.integer "failed_jobs", default: 0, null: false
    t.datetime "enqueued_at"
    t.datetime "finished_at"
    t.datetime "failed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active_job_batch_id"], name: "index_solid_queue_batches_on_active_job_batch_id", unique: true
    t.index ["finished_at"], name: "index_solid_queue_batches_on_finished_at"
  end

  create_table "solid_queue_blocked_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.string "concurrency_key", null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.index ["concurrency_key", "priority", "job_id"], name: "index_solid_queue_blocked_executions_for_release"
    t.index ["expires_at", "concurrency_key"], name: "index_solid_queue_blocked_executions_for_maintenance"
    t.index ["job_id"], name: "index_solid_queue_blocked_executions_on_job_id", unique: true
  end

  create_table "solid_queue_claimed_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.bigint "process_id"
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_claimed_executions_on_job_id", unique: true
    t.index ["process_id", "job_id"], name: "index_solid_queue_claimed_executions_on_process_id_and_job_id"
  end

  create_table "solid_queue_failed_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.text "error"
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_failed_executions_on_job_id", unique: true
  end

  create_table "solid_queue_jobs", force: :cascade do |t|
    t.string "queue_name", null: false
    t.string "class_name", null: false
    t.text "arguments"
    t.integer "priority", default: 0, null: false
    t.string "active_job_id"
    t.datetime "scheduled_at"
    t.datetime "finished_at"
    t.string "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "batch_id"
    t.index ["active_job_id"], name: "index_solid_queue_jobs_on_active_job_id"
    t.index ["batch_id"], name: "index_solid_queue_jobs_on_batch_id"
    t.index ["class_name"], name: "index_solid_queue_jobs_on_class_name"
    t.index ["finished_at"], name: "index_solid_queue_jobs_on_finished_at"
    t.index ["queue_name", "finished_at"], name: "index_solid_queue_jobs_for_filtering"
    t.index ["scheduled_at", "finished_at"], name: "index_solid_queue_jobs_for_alerting"
  end

  create_table "solid_queue_pauses", force: :cascade do |t|
    t.string "queue_name", null: false
    t.datetime "created_at", null: false
    t.index ["queue_name"], name: "index_solid_queue_pauses_on_queue_name", unique: true
  end

  create_table "solid_queue_processes", force: :cascade do |t|
    t.string "kind", null: false
    t.datetime "last_heartbeat_at", null: false
    t.bigint "supervisor_id"
    t.integer "pid", null: false
    t.string "hostname"
    t.text "metadata"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.index ["last_heartbeat_at"], name: "index_solid_queue_processes_on_last_heartbeat_at"
    t.index ["name", "supervisor_id"], name: "index_solid_queue_processes_on_name_and_supervisor_id", unique: true
    t.index ["supervisor_id"], name: "index_solid_queue_processes_on_supervisor_id"
  end

  create_table "solid_queue_ready_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_ready_executions_on_job_id", unique: true
    t.index ["priority", "job_id"], name: "index_solid_queue_poll_all"
    t.index ["queue_name", "priority", "job_id"], name: "index_solid_queue_poll_by_queue"
  end

  create_table "solid_queue_recurring_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "task_key", null: false
    t.datetime "run_at", null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_recurring_executions_on_job_id", unique: true
    t.index ["task_key", "run_at"], name: "index_solid_queue_recurring_executions_on_task_key_and_run_at", unique: true
  end

  create_table "solid_queue_recurring_tasks", force: :cascade do |t|
    t.string "key", null: false
    t.string "schedule", null: false
    t.string "command", limit: 2048
    t.string "class_name"
    t.text "arguments"
    t.string "queue_name"
    t.integer "priority", default: 0
    t.boolean "static", default: true, null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_solid_queue_recurring_tasks_on_key", unique: true
    t.index ["static"], name: "index_solid_queue_recurring_tasks_on_static"
  end

  create_table "solid_queue_scheduled_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.datetime "scheduled_at", null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_scheduled_executions_on_job_id", unique: true
    t.index ["scheduled_at", "priority", "job_id"], name: "index_solid_queue_dispatch_all"
  end

  create_table "solid_queue_semaphores", force: :cascade do |t|
    t.string "key", null: false
    t.integer "value", default: 1, null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["expires_at"], name: "index_solid_queue_semaphores_on_expires_at"
    t.index ["key", "value"], name: "index_solid_queue_semaphores_on_key_and_value"
    t.index ["key"], name: "index_solid_queue_semaphores_on_key", unique: true
  end

  create_table "store_box_location_mappings", force: :cascade do |t|
    t.bigint "store_box_integration_id", null: false
    t.bigint "location_id", null: false
    t.string "warehouse_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["location_id"], name: "index_store_box_location_mappings_on_location_id", unique: true
    t.index ["store_box_integration_id"], name: "index_store_box_location_mappings_on_store_box_integration_id"
  end

  create_table "store_box_result_mappings", force: :cascade do |t|
    t.bigint "store_box_integration_id", null: false
    t.string "result", null: false
    t.string "action", null: false
    t.boolean "restock", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["store_box_integration_id", "result"], name: "idx_on_store_box_integration_id_result_cb18ba651d", unique: true
    t.index ["store_box_integration_id"], name: "index_store_box_result_mappings_on_store_box_integration_id"
  end

  create_table "store_box_returns", force: :cascade do |t|
    t.bigint "store_box_integration_id", null: false
    t.bigint "return_order_id", null: false
    t.string "remote_id", null: false
    t.string "warehouse_id", null: false
    t.integer "status", default: 0, null: false
    t.jsonb "results", default: [], null: false
    t.string "action"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["return_order_id"], name: "index_store_box_returns_on_return_order_id", unique: true
    t.index ["store_box_integration_id"], name: "index_store_box_returns_on_store_box_integration_id"
  end

  create_table "store_box_send_attempts", force: :cascade do |t|
    t.bigint "store_box_integration_id", null: false
    t.bigint "return_order_id", null: false
    t.text "error", null: false
    t.datetime "created_at", null: false
    t.index ["return_order_id"], name: "index_store_box_send_attempts_on_return_order_id"
    t.index ["store_box_integration_id"], name: "index_store_box_send_attempts_on_store_box_integration_id"
  end

  create_table "timeline_events", force: :cascade do |t|
    t.bigint "return_order_id", null: false
    t.integer "kind", null: false
    t.jsonb "data", default: {}, null: false
    t.datetime "created_at", null: false
    t.index ["return_order_id"], name: "index_timeline_events_on_return_order_id"
  end

  create_table "users", force: :cascade do |t|
    t.bigint "shop_id", null: false
    t.string "email", null: false
    t.string "password_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["shop_id"], name: "index_users_on_shop_id"
  end

  create_table "variants", force: :cascade do |t|
    t.bigint "product_id", null: false
    t.string "sku", null: false
    t.string "title", null: false
    t.integer "price_cents", null: false
    t.string "currency", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["product_id"], name: "index_variants_on_product_id"
  end

  add_foreign_key "customers", "shops"
  add_foreign_key "exchanges", "return_items"
  add_foreign_key "exchanges", "return_orders"
  add_foreign_key "exchanges", "variants"
  add_foreign_key "integrations", "shops"
  add_foreign_key "inventory_levels", "locations"
  add_foreign_key "inventory_levels", "variants"
  add_foreign_key "locations", "shops"
  add_foreign_key "order_line_items", "orders"
  add_foreign_key "order_line_items", "variants"
  add_foreign_key "orders", "customers"
  add_foreign_key "orders", "shops"
  add_foreign_key "products", "shops"
  add_foreign_key "refunds", "return_orders"
  add_foreign_key "reservations", "exchanges"
  add_foreign_key "reservations", "locations"
  add_foreign_key "reservations", "variants"
  add_foreign_key "return_items", "order_line_items"
  add_foreign_key "return_items", "return_orders"
  add_foreign_key "return_items", "variants"
  add_foreign_key "return_items", "variants", column: "exchange_variant_id"
  add_foreign_key "return_orders", "customers"
  add_foreign_key "return_orders", "locations"
  add_foreign_key "return_orders", "orders"
  add_foreign_key "return_orders", "shipping_methods"
  add_foreign_key "return_orders", "shops"
  add_foreign_key "shipments", "return_orders"
  add_foreign_key "shipping_methods", "shops"
  add_foreign_key "solid_queue_batch_executions", "solid_queue_batches", column: "batch_id", on_delete: :cascade
  add_foreign_key "solid_queue_batch_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_recurring_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "store_box_location_mappings", "integrations", column: "store_box_integration_id"
  add_foreign_key "store_box_location_mappings", "locations"
  add_foreign_key "store_box_result_mappings", "integrations", column: "store_box_integration_id"
  add_foreign_key "store_box_returns", "integrations", column: "store_box_integration_id"
  add_foreign_key "store_box_returns", "return_orders"
  add_foreign_key "store_box_send_attempts", "integrations", column: "store_box_integration_id"
  add_foreign_key "store_box_send_attempts", "return_orders"
  add_foreign_key "timeline_events", "return_orders"
  add_foreign_key "users", "shops"
  add_foreign_key "variants", "products"
end

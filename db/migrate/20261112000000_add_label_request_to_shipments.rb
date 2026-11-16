class AddLabelRequestToShipments < ActiveRecord::Migration[7.2]
  def change
    add_column :shipments, :label_request_id, :string
    add_column :shipments, :error, :string
    add_index :shipments, :label_request_id
  end
end

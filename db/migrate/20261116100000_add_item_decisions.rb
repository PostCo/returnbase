class AddItemDecisions < ActiveRecord::Migration[7.2]
  def change
    add_column :return_items, :outcome, :integer
    add_column :return_items, :restock, :boolean
    add_reference :exchanges, :return_item, foreign_key: true
  end
end

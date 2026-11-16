class AddUsersAndExchangeStatus < ActiveRecord::Migration[7.2]
  def change
    create_table :users do |t|
      t.references :shop, null: false, foreign_key: true
      t.string :email, null: false
      t.string :password_digest, null: false
      t.timestamps
      t.index :email, unique: true
    end

    add_column :exchanges, :status, :integer, null: false, default: 0
  end
end

class CreateUsers < ActiveRecord::Migration[8.0]
  def change
    create_table :users do |t|
      t.string :name, null: false
      t.string :email, null: false
      t.string :pin_digest, null: false
      t.decimal :balance, precision: 15, scale: 2, default: 0.00, null: false
      t.string :auth_token
      t.timestamps
    end
    add_index :users, :email, unique: true
    add_index :users, :auth_token, unique: true
  end
end

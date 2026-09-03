class AddCryptographicIdentityToWorkers < ActiveRecord::Migration[8.1]
  def change
    add_column :workers, :public_key_pem, :text
    add_column :workers, :key_fingerprint, :string
    add_column :workers, :enrolled_at, :datetime
    add_column :workers, :identity_rotated_at, :datetime
    add_index :workers, :key_fingerprint, unique: true

    create_table :worker_request_nonces do |t|
      t.references :worker, null: false, foreign_key: true
      t.string :nonce_digest, null: false
      t.datetime :expires_at, null: false
      t.timestamps
    end
    add_index :worker_request_nonces, %i[worker_id nonce_digest], unique: true
    add_index :worker_request_nonces, :expires_at
  end
end

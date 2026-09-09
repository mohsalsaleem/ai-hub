class AddHomebaseBrowserIdentity < ActiveRecord::Migration[8.1]
  def change
    create_table :external_identities do |t|
      t.references :user, null: false, foreign_key: true
      t.string :issuer, null: false
      t.string :subject, null: false
      t.timestamps
    end
    add_index :external_identities, [ :issuer, :subject ], unique: true
    add_index :external_identities, [ :user_id, :issuer ], unique: true
    add_column :sessions, :homebase_issuer, :string
    add_column :sessions, :homebase_subject, :string
    add_column :sessions, :homebase_tokens, :text
    add_column :sessions, :homebase_expires_at, :datetime
    create_table :homebase_login_transactions do |t|
      t.string :token_digest, null: false
      t.string :purpose, null: false
      t.bigint :user_id
      t.bigint :browser_session_id
      t.string :issuer, null: false
      t.string :state, null: false
      t.string :nonce, null: false
      t.string :verifier, null: false
      t.string :return_to, null: false
      t.datetime :expires_at, null: false
      t.timestamps
    end
    add_index :homebase_login_transactions, :token_digest, unique: true
    add_index :homebase_login_transactions, :expires_at
  end
end

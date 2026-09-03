class AddWorkerEnrollmentGrantsAndIdentityEvents < ActiveRecord::Migration[8.1]
  def up
    create_table :worker_enrollment_grants do |t|
      t.references :worker, null: false, foreign_key: true
      t.string :token_digest, null: false
      t.string :token_hint
      t.datetime :expires_at, null: false
      t.datetime :used_at
      t.datetime :revoked_at
      t.timestamps
    end
    add_index :worker_enrollment_grants, :token_digest, unique: true
    add_index :worker_enrollment_grants, :expires_at

    create_table :worker_identity_events do |t|
      t.references :worker, null: false, foreign_key: true
      t.string :event_type, null: false
      t.string :key_fingerprint
      t.json :details, default: {}, null: false
      t.datetime :created_at, null: false
    end
    add_index :worker_identity_events, %i[worker_id created_at]

    execute <<~SQL.squish
      INSERT INTO worker_enrollment_grants
        (worker_id, token_digest, token_hint, expires_at, created_at, updated_at)
      SELECT id, token_digest, token_hint, DATETIME('now', '+7 days'), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
      FROM workers
      WHERE enrolled_at IS NULL
    SQL
  end

  def down
    drop_table :worker_identity_events
    drop_table :worker_enrollment_grants
  end
end

class CreateAiHubCore < ActiveRecord::Migration[8.1]
  def change
    create_table :hub_applications do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.string :token_digest, null: false
      t.boolean :active, null: false, default: true
      t.timestamps
      t.index :slug, unique: true
      t.index :token_digest, unique: true
    end

    create_table :workers do |t|
      t.string :name, null: false
      t.string :token_digest, null: false
      t.string :reported_id
      t.string :version
      t.json :capabilities, null: false, default: []
      t.json :latest_metrics, null: false, default: {}
      t.datetime :last_seen_at
      t.datetime :metrics_reported_at
      t.boolean :active, null: false, default: true
      t.timestamps
      t.index :token_digest, unique: true
    end

    create_table :task_definitions do |t|
      t.references :hub_application, null: false, foreign_key: true
      t.string :key, null: false
      t.integer :version, null: false
      t.string :digest, null: false
      t.string :executor, null: false, default: "structured_generation"
      t.text :instructions, null: false
      t.json :input_schema, null: false
      t.json :output_schema, null: false
      t.json :requirements, null: false, default: {}
      t.boolean :active, null: false, default: true
      t.timestamps
      t.index [ :hub_application_id, :key, :version ], unique: true
      t.index :digest, unique: true
    end

    create_table :jobs do |t|
      t.references :hub_application, null: false, foreign_key: true
      t.references :task_definition, null: false, foreign_key: true
      t.references :worker, foreign_key: true
      t.string :public_id, null: false
      t.string :idempotency_key, null: false
      t.string :status, null: false, default: "queued"
      t.integer :priority, null: false, default: 0
      t.integer :attempts, null: false, default: 0
      t.integer :max_attempts, null: false, default: 5
      t.json :input, null: false
      t.json :output
      t.json :error
      t.string :lease_token_digest
      t.datetime :available_at, null: false
      t.datetime :leased_until
      t.datetime :completed_at
      t.timestamps
      t.index :public_id, unique: true
      t.index [ :hub_application_id, :idempotency_key ], unique: true
      t.index [ :status, :available_at, :priority ], name: "index_jobs_for_claiming"
    end
  end
end

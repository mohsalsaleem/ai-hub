class CreateJobExecutions < ActiveRecord::Migration[8.1]
  def change
    create_table :job_executions do |t|
      t.references :job, null: false, foreign_key: true
      t.integer :attempt_number, null: false
      t.references :worker, null: true, foreign_key: { on_delete: :nullify }
      t.references :worker_pool, null: true, foreign_key: { on_delete: :nullify }
      t.references :consumer_organization, null: false, foreign_key: { to_table: :organizations }
      t.references :provider_organization, null: false, foreign_key: { to_table: :organizations }
      t.string :consumer_organization_name, null: false
      t.string :provider_organization_name, null: false
      t.string :application_name, null: false
      t.string :task_reference, null: false
      t.string :worker_name, null: false
      t.string :worker_pool_name
      t.boolean :shared, null: false
      t.string :outcome, default: "running", null: false
      t.string :failure_code
      t.boolean :usage_reported, default: false, null: false
      t.integer :usage_schema_version
      t.string :llm_model
      t.bigint :input_tokens
      t.bigint :output_tokens
      t.bigint :total_tokens
      t.bigint :model_duration_ms
      t.bigint :hub_duration_ms
      t.datetime :started_at, null: false
      t.datetime :finished_at
      t.timestamps

      t.index [ :job_id, :attempt_number ], unique: true
      t.index [ :consumer_organization_id, :finished_at ], name: "index_executions_on_consumer_and_finished"
      t.index [ :provider_organization_id, :finished_at ], name: "index_executions_on_provider_and_finished"
      t.index [ :shared, :finished_at ]
    end
  end
end

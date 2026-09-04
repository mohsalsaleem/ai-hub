class AddRoutingEvidenceToJobs < ActiveRecord::Migration[8.1]
  def change
    add_reference :jobs, :worker_pool, foreign_key: { on_delete: :nullify }
    add_column :jobs, :minimum_worker_trust, :string, default: "owner", null: false

    reversible do |direction|
      direction.up do
        execute <<~SQL.squish
          UPDATE jobs
          SET worker_pool_id = (
            SELECT hub_applications.worker_pool_id
            FROM hub_applications
            WHERE hub_applications.id = jobs.hub_application_id
          ),
          minimum_worker_trust = (
            SELECT hub_applications.minimum_worker_trust
            FROM hub_applications
            WHERE hub_applications.id = jobs.hub_application_id
          )
        SQL
      end
    end

    create_table :routing_decisions do |t|
      t.references :job, null: false, foreign_key: true
      t.references :worker_pool, foreign_key: { on_delete: :nullify }
      t.references :worker, foreign_key: { on_delete: :nullify }
      t.string :outcome, null: false
      t.string :reason, null: false
      t.json :evidence, default: {}, null: false
      t.timestamps
    end
    add_index :routing_decisions, %i[job_id created_at]
  end
end

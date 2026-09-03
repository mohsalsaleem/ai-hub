class AddTrustAwareWorkerRouting < ActiveRecord::Migration[8.1]
  def change
    create_table :worker_pools do |t|
      t.references :organization, null: false, foreign_key: true
      t.string :name, null: false
      t.string :slug, null: false
      t.timestamps
    end
    add_index :worker_pools, %i[organization_id slug], unique: true

    create_table :worker_pool_memberships do |t|
      t.references :worker_pool, null: false, foreign_key: true
      t.references :worker, null: false, foreign_key: true
      t.timestamps
    end
    add_index :worker_pool_memberships, %i[worker_pool_id worker_id], unique: true

    add_column :workers, :trust_tier, :string, default: "owner", null: false
    add_column :hub_applications, :minimum_worker_trust, :string, default: "owner", null: false
    add_reference :hub_applications, :worker_pool, foreign_key: true
  end
end

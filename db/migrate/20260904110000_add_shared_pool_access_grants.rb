class AddSharedPoolAccessGrants < ActiveRecord::Migration[8.1]
  def change
    add_column :worker_pools, :access_mode, :string, default: "private", null: false

    create_table :worker_pool_access_grants do |t|
      t.references :worker_pool, null: false, foreign_key: true
      t.references :organization, null: false, foreign_key: true
      t.timestamps
    end
    add_index :worker_pool_access_grants, %i[worker_pool_id organization_id],
      unique: true, name: "index_pool_access_grants_on_pool_and_organization"
  end
end

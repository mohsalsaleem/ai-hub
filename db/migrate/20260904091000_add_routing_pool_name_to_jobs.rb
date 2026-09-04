class AddRoutingPoolNameToJobs < ActiveRecord::Migration[8.1]
  def change
    add_column :jobs, :routing_pool_name, :string

    reversible do |direction|
      direction.up do
        execute <<~SQL.squish
          UPDATE jobs
          SET routing_pool_name = (
            SELECT worker_pools.name
            FROM worker_pools
            WHERE worker_pools.id = jobs.worker_pool_id
          )
        SQL
      end
    end
  end
end

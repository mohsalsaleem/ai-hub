class AddParticipationPolicyToWorkers < ActiveRecord::Migration[8.1]
  def change
    add_column :workers, :participation_mode, :string, default: "private", null: false
    add_column :workers, :paused_at, :datetime
    add_column :workers, :availability_timezone, :string, default: "UTC", null: false
    add_column :workers, :availability_days, :json,
      default: %w[monday tuesday wednesday thursday friday saturday sunday], null: false
    add_column :workers, :availability_starts_at, :string
    add_column :workers, :availability_ends_at, :string
    add_column :workers, :max_concurrent_jobs, :integer, default: 1, null: false
  end
end

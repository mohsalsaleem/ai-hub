require "test_helper"

class WorkerPoolMembershipTest < ActiveSupport::TestCase
  test "worker and pool must belong to the same organization" do
    worker, = Worker.issue!(organization: organizations(:one), name: "Local")
    pool = organizations(:two).worker_pools.create!(name: "Other")

    membership = WorkerPoolMembership.new(worker:, worker_pool: pool)

    assert_not membership.valid?
    assert_includes membership.errors[:worker], "must belong to the pool organization"
  end
end

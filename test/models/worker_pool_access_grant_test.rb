require "test_helper"

class WorkerPoolAccessGrantTest < ActiveSupport::TestCase
  test "only shared pools can grant another organization access" do
    pool = organizations(:one).worker_pools.create!(name: "Private GPU")
    grant = pool.worker_pool_access_grants.new(organization: organizations(:two))

    assert_not grant.valid?
    assert_includes grant.errors[:worker_pool], "must be shared"

    pool.update!(access_mode: "shared")
    assert grant.valid?
  end

  test "a pool cannot grant access to its owner" do
    pool = organizations(:one).worker_pools.create!(name: "Shared GPU", access_mode: "shared")
    grant = pool.worker_pool_access_grants.new(organization: organizations(:one))

    assert_not grant.valid?
    assert_includes grant.errors[:organization], "already owns this pool"
  end

  test "revoking access clears future application routing" do
    pool = organizations(:one).worker_pools.create!(name: "Shared GPU", access_mode: "shared")
    grant = pool.worker_pool_access_grants.create!(organization: organizations(:two))
    application, = HubApplication.issue!(organization: organizations(:two), name: "Consumer", slug: "consumer")
    application.update!(worker_pool: pool, minimum_worker_trust: "external")

    grant.destroy!

    assert_nil application.reload.worker_pool
  end
end

require "test_helper"

class TenantConsoleTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:one))
    @application, = HubApplication.issue!(organization: organizations(:one), name: "First App", slug: "first-app")
    @other_application, = HubApplication.issue!(organization: organizations(:two), name: "Private App", slug: "private-app")
  end

  test "application pages only expose the current organization" do
    get applications_path
    assert_response :success
    assert_match "First App", response.body
    assert_no_match "Private App", response.body

    get application_path(@other_application)
    assert_response :not_found
  end

  test "owner creates an application and sees its token once" do
    assert_difference "organizations(:one).hub_applications.count", 1 do
      post applications_path, params: { hub_application: { name: "Created App", slug: "created-app" } }
    end
    follow_redirect!
    assert_response :success
    assert_match(/aih_[0-9a-f]{48}/, response.body)
    get request.path
    assert_no_match(/aih_[0-9a-f]{48}/, response.body)
  end

  test "owner configures worker pools and application trust policy" do
    post worker_pools_path, params: { worker_pool: { name: "Trusted GPU" } }
    pool = organizations(:one).worker_pools.find_by!(slug: "trusted-gpu")

    get workers_path
    assert_response :success
    assert_select "button", "Issue worker token"
    assert_select ".pool-pill", text: /Trusted GPU/

    worker, = Worker.issue!(organization: organizations(:one), name: "Remote GPU")
    patch worker_path(worker), params: { worker: { trust_tier: "verified", worker_pool_ids: [ pool.id ] } }
    assert_redirected_to workers_path(anchor: "worker-#{worker.id}")
    assert_equal "verified", worker.reload.trust_tier
    assert_equal [ pool ], worker.worker_pools

    patch application_path(@application), params: {
      hub_application: { minimum_worker_trust: "verified", worker_pool_id: pool.id }
    }
    assert_redirected_to application_path(@application)
    assert_equal "verified", @application.reload.minimum_worker_trust
    assert_equal pool, @application.worker_pool

    get application_path(@application)
    assert_response :success
    assert_select ".routing-policy", text: /Trusted GPU/
  end

  test "routing resources cannot cross organization boundaries" do
    other_pool = organizations(:two).worker_pools.create!(name: "Other pool")
    worker, = Worker.issue!(organization: organizations(:one), name: "Local")

    patch worker_path(worker), params: { worker: { trust_tier: "owner", worker_pool_ids: [ other_pool.id ] } }
    assert_empty worker.reload.worker_pools

    patch application_path(@application), params: {
      hub_application: { minimum_worker_trust: "external", worker_pool_id: other_pool.id }
    }
    assert_response :unprocessable_entity
    assert_nil @application.reload.worker_pool
  end
end

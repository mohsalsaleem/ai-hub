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
    assert_select ".nav-primary", text: /Overview.*Applications.*Activity.*Hosting/m
    assert_select ".nav-secondary", text: /Documentation.*Settings/m
    assert_select ".nav-link", text: "Task definitions", count: 0

    get application_path(@other_application)
    assert_response :not_found
  end

  test "application owns its task definition navigation" do
    definition = @application.task_definitions.create!(key: "first.extract", version: 1,
      executor: "structured_generation", instructions: "Extract structured data.",
      input_schema: { type: "object" }, output_schema: { type: "object" }, requirements: {})

    get application_path(@application)
    assert_response :success
    assert_select "nav[aria-label='Application sections']", text: /Task definitions/

    get task_definitions_application_path(@application)
    assert_response :success
    assert_select "nav[aria-label='Application sections'] a.is-active", text: "Task definitions"
    assert_select "a", text: definition.reference

    get jobs_application_path(@application)
    assert_response :success
    assert_select "nav[aria-label='Application sections'] a.is-active", text: "Runs"

    get settings_application_path(@application)
    assert_response :success
    assert_select "nav[aria-label='Application sections'] a.is-active", text: "Settings"

    get task_definition_path(definition)
    assert_response :success
    assert_select "nav[aria-label='Breadcrumb']", text: /Applications.*First App.*Task definitions/m
    assert_select "a.nav-link.is-active", text: "Applications"
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

    get hosting_path
    assert_response :success
    assert_select "h1", "Hosting"
    assert_select "button", "Issue worker token"
    assert_select ".pool-pill", text: /Trusted GPU/

    worker, = Worker.issue!(organization: organizations(:one), name: "Remote GPU")
    patch worker_path(worker), params: { worker: { trust_tier: "verified", worker_pool_ids: [ pool.id ] } }
    assert_redirected_to hosting_path(anchor: "worker-#{worker.id}")
    assert_equal "verified", worker.reload.trust_tier
    assert_equal [ pool ], worker.worker_pools

    patch application_path(@application), params: {
      hub_application: { minimum_worker_trust: "verified", worker_pool_id: pool.id }
    }
    assert_redirected_to settings_application_path(@application)
    assert_equal "verified", @application.reload.minimum_worker_trust
    assert_equal pool, @application.worker_pool

    get settings_application_path(@application)
    assert_response :success
    assert_select ".routing-policy", text: /Trusted GPU/
  end

  test "owner configures and pauses provider participation" do
    worker, = Worker.issue!(organization: organizations(:one), name: "Night GPU")

    patch worker_path(worker), params: { worker: {
      trust_tier: "owner", participation_mode: "shared", max_concurrent_jobs: 3,
      availability_timezone: "Abu Dhabi", availability_days: %w[monday tuesday],
      availability_starts_at: "22:00", availability_ends_at: "06:00", worker_pool_ids: []
    } }

    worker.reload
    assert_equal "shared", worker.participation_mode
    assert_equal 3, worker.max_concurrent_jobs
    assert_equal %w[monday tuesday], worker.availability_days
    assert_equal "Abu Dhabi", worker.availability_timezone

    post pause_worker_path(worker)
    assert worker.reload.paused?
    post resume_worker_path(worker)
    assert_not worker.reload.paused?

    get hosting_path
    assert_response :success
    assert_select "article#worker-#{worker.id}", text: /Shared capacity.*Mon, Tue, 22:00 to 06:00/m
  end

  test "provider grants a consumer access without exposing workers" do
    post worker_pools_path, params: { worker_pool: { name: "Shared GPU", access_mode: "shared" } }
    pool = organizations(:one).worker_pools.find_by!(slug: "shared-gpu")
    pool.transition_operator_status!("approved")
    provider_worker, = Worker.issue!(organization: organizations(:one), name: "Provider machine")

    post worker_pool_access_grants_path(pool), params: {
      worker_pool_access_grant: { organization_slug: organizations(:two).slug }
    }
    assert_redirected_to hosting_path(anchor: "pool-#{pool.id}")
    assert pool.accessible_to?(organizations(:two))

    sign_out
    sign_in_as(users(:two))
    get settings_application_path(@other_application)

    assert_response :success
    assert_select "select[name='hub_application[worker_pool_id]'] option", text: "Shared GPU"
    assert_no_match provider_worker.name, response.body

    patch application_path(@other_application), params: {
      hub_application: { minimum_worker_trust: "verified", worker_pool_id: pool.id }
    }
    assert_redirected_to settings_application_path(@other_application)
    assert_equal pool, @other_application.reload.worker_pool
  end

  test "an organization cannot manage another provider's pool grants" do
    pool = organizations(:two).worker_pools.create!(name: "Other shared GPU", access_mode: "shared")

    post worker_pool_access_grants_path(pool), params: {
      worker_pool_access_grant: { organization_slug: organizations(:one).slug }
    }

    assert_response :not_found
    assert_empty pool.worker_pool_access_grants
  end

  test "product entry points expose activity hosting and settings" do
    get activity_path
    assert_response :success
    assert_select "h1", "Activity"

    get hosting_path
    assert_response :success
    assert_select "h1", "Hosting"

    get settings_path
    assert_response :success
    assert_select "h1", "Settings"
    assert_select "nav[aria-label='Settings sections'] a.is-active", text: "Organization"
  end

  test "consumer members do not see provider hosting navigation" do
    sign_out
    consumer = User.create!(email_address: "consumer@example.com", password: "password")
    organizations(:one).memberships.create!(user: consumer, role: "member")
    sign_in_as(consumer)

    get applications_path
    assert_response :success
    assert_select ".nav-link", text: "Hosting", count: 0

    get hosting_path
    assert_redirected_to dashboard_path

    get settings_application_path(@application)
    assert_response :success
    assert_select "form", text: /Save policy/, count: 0
    assert_select "button", text: /Rotate token|Revoke application/, count: 0
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

  test "consumer run detail shows usage without provider worker identity" do
    worker, = Worker.issue!(organization: organizations(:one), name: "Private machine name")
    definition = @application.task_definitions.create!(key: "first.metered", version: 1,
      instructions: "Generate.", input_schema: { type: "object" }, output_schema: { type: "object" })
    job = @application.jobs.create!(task_definition: definition, idempotency_key: "metered-detail", input: {})
    job.update!(attempts: 1, status: "leased", worker:, leased_until: 1.minute.from_now,
      lease_token_digest: Job.token_digest("lease"))
    JobExecution.start_for!(job:, worker:).finalize!(outcome: "completed", usage: UsageReport.normalize(
      input_tokens: 8, output_tokens: 4, model: "provider-internal-model", duration_ms: 40
    ))

    get job_path(job.public_id)

    assert_response :success
    assert_select ".usage-summary", text: /Execution usage.*12/m
    assert_select "table", text: /#1.*Completed.*8.*4.*12.*40 ms/m
    assert_no_match "Private machine name", response.body
    assert_no_match "provider-internal-model", response.body
  end

  test "provider hosting shows scoped execution totals without consumer payloads" do
    worker, = Worker.issue!(organization: organizations(:one), name: "Meter worker")
    definition = @application.task_definitions.create!(key: "first.hosting", version: 1,
      instructions: "Generate.", input_schema: { type: "object" }, output_schema: { type: "object" })
    job = @application.jobs.create!(task_definition: definition, idempotency_key: "hosting-usage",
      input: { secret: "do not show" })
    job.update!(attempts: 1, status: "leased", worker:, leased_until: 1.minute.from_now,
      lease_token_digest: Job.token_digest("lease"))
    JobExecution.start_for!(job:, worker:).finalize!(outcome: "completed",
      usage: UsageReport.normalize(total_tokens: 9, llm_model: "provider-llm", duration_ms: 30))

    get hosting_path

    assert_response :success
    assert_select ".usage-summary", text: /Usage.*30 days.*9/m
    assert_select "table", text: /Meter worker.*provider-llm.*Private.*Completed.*9.*30 ms/m
    assert_no_match "do not show", response.body
  end
end

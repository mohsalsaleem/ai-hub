require "test_helper"

class PlatformConsoleTest < ActionDispatch::IntegrationTest
  setup do
    @provider = organizations(:one)
    @consumer = organizations(:two)
    @operator = PlatformOperator.create!(email_address: "operator@example.com",
      password: "operator-password")
    @pool = @provider.worker_pools.create!(name: "Shared GPU", access_mode: "shared")
    @grant = @pool.worker_pool_access_grants.create!(organization: @consumer)
    sign_in_as_platform_operator(@operator)
  end

  test "tenant authentication does not grant platform access" do
    sign_out_platform_operator
    sign_in_as(users(:two))

    get platform_root_path

    assert_redirected_to new_platform_session_path
  end

  test "platform authentication does not create a tenant session" do
    assert_nil cookies[:session_id]

    get platform_root_path

    assert_response :success
    assert_select "nav[aria-label='Platform navigation']", text: /Operations/
    assert cookies[:platform_session_id]
  end

  test "operator sees an isolated metadata-only console" do
    @pool.transition_operator_status!("approved")
    worker, = Worker.issue!(organization: @provider, name: "Provider GPU",
      participation_mode: "shared", trust_tier: "verified")
    worker.worker_pools << @pool
    application, = HubApplication.issue!(organization: @consumer, name: "Consumer", slug: "consumer")
    application.update!(worker_pool: @pool, minimum_worker_trust: "verified")
    definition = application.task_definitions.create!(key: "consumer.extract", version: 1,
      executor: "structured_generation", instructions: "Extract a title.",
      input_schema: { type: "object" }, output_schema: { type: "object" })
    application.jobs.create!(task_definition: definition, idempotency_key: "platform-visible",
      input: { private_message: "never render this value" })

    get platform_root_path

    assert_response :success
    assert_select "h1", "Platform operations"
    assert_select "nav[aria-label='Platform navigation']", text: /Operations.*Tenant console/m
    assert_select "#pool-#{@pool.id}", text: /Shared GPU.*First organization.*Approved/m
    assert_match application.jobs.first.public_id, response.body
    assert_no_match "never render this value", response.body
    assert_no_match "Extract a title", response.body
  end

  test "operator approves a pending shared pool and records an audit event" do
    assert_not @pool.accessible_to?(@consumer)

    assert_difference "PlatformAuditEvent.count", 1 do
      patch approve_platform_worker_pool_path(@pool)
    end

    assert_redirected_to platform_root_path(anchor: "pool-#{@pool.id}")
    assert_equal "approved", @pool.reload.operator_status
    assert @pool.accessible_to?(@consumer)
    event = PlatformAuditEvent.last
    assert_equal "shared_pool.approved", event.action
    assert_equal @operator, event.platform_operator
    assert_equal @pool.id, event.subject_id
  end

  test "suspension stops an existing queued shared run from being claimed" do
    @pool.transition_operator_status!("approved")
    worker, worker_token = Worker.issue!(organization: @provider, name: "Provider GPU",
      participation_mode: "shared", trust_tier: "verified")
    worker.worker_pools << @pool
    application, = HubApplication.issue!(organization: @consumer, name: "Consumer", slug: "consumer")
    application.update!(worker_pool: @pool, minimum_worker_trust: "verified")
    definition = application.task_definitions.create!(key: "consumer.extract", version: 1,
      executor: "structured_generation", instructions: "Extract.",
      input_schema: { type: "object" }, output_schema: { type: "object" })
    job = application.jobs.create!(task_definition: definition, idempotency_key: "suspended", input: {})

    patch suspend_platform_worker_pool_path(@pool)
    post api_v1_worker_claims_path,
      headers: { "Authorization" => "Bearer #{worker_token}", "X-Worker-Id" => "provider",
                 "X-Worker-Capabilities" => "structured_generation" }, as: :json
    queued_during_suspension = application.jobs.create!(task_definition: definition,
      idempotency_key: "queued-during-suspension", input: {})
    assert_equal "pool_suspended", RoutingDiagnosis.new(queued_during_suspension.reload).call.code
    assert_equal "suspended", @pool.reload.operator_status
    assert_nil response.parsed_body["job"]
    assert_equal "queued", job.reload.status
    assert_not @pool.accessible_to?(@consumer)
  end

  test "operator revocation removes grants and future routing selections" do
    @pool.transition_operator_status!("approved")
    application, = HubApplication.issue!(organization: @consumer, name: "Consumer", slug: "consumer")
    application.update!(worker_pool: @pool, minimum_worker_trust: "verified")

    assert_difference "PlatformAuditEvent.count", 1 do
      patch revoke_platform_worker_pool_path(@pool)
    end

    assert_equal "revoked", @pool.reload.operator_status
    assert_empty @pool.worker_pool_access_grants
    assert_nil application.reload.worker_pool
    assert_equal "shared_pool.revoked", PlatformAuditEvent.last.action
  end
end

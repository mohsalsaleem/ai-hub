require "test_helper"

class SharedPoolRoutingTest < ActionDispatch::IntegrationTest
  setup do
    @provider = organizations(:one)
    @consumer = organizations(:two)
    @pool = @provider.worker_pools.create!(name: "Shared GPU", access_mode: "shared")
    @pool.worker_pool_access_grants.create!(organization: @consumer)
    @worker, @worker_token = Worker.issue!(organization: @provider, name: "Provider GPU",
      participation_mode: "shared", trust_tier: "verified")
    @worker.worker_pools << @pool
    @application, @application_token = HubApplication.issue!(organization: @consumer,
      name: "Consumer App", slug: "consumer-app")
    @application.update!(worker_pool: @pool, minimum_worker_trust: "verified")
    @definition = @application.task_definitions.create!(key: "consumer.extract", version: 1,
      executor: "structured_generation", instructions: "Extract a title.",
      input_schema: { type: "object", required: [ "text" ], properties: { text: { type: "string" } } },
      output_schema: { type: "object", required: [ "title" ], properties: { title: { type: "string" } } })
  end

  def worker_headers
    { "Authorization" => "Bearer #{@worker_token}", "X-Worker-Id" => "provider-worker",
      "X-Worker-Capabilities" => "structured_generation" }
  end

  def application_headers = { "Authorization" => "Bearer #{@application_token}" }

  test "a shared provider claims and completes a granted consumer run" do
    job = @application.jobs.create!(task_definition: @definition,
      idempotency_key: "shared-run", input: { text: "Hello" })

    post api_v1_worker_claims_path, headers: worker_headers, as: :json
    assert_response :success
    claim = response.parsed_body
    assert_equal job.public_id, claim.dig("job", "id")

    get api_v1_worker_task_definition_path(@definition.digest), headers: worker_headers
    assert_response :success
    assert_equal "Extract a title.", response.parsed_body.fetch("instructions")

    post api_v1_worker_job_complete_path(job.public_id), headers: worker_headers, as: :json,
      params: { lease_token: claim.fetch("lease_token"), output: { title: "Hello" } }
    assert_response :success

    get api_v1_job_path(job.public_id), headers: application_headers
    payload = response.parsed_body
    assert_equal "completed", payload.fetch("status")
    assert_equal "Shared GPU", payload.dig("routing", "pool")
    assert_not_includes payload.to_json, @worker.name
    assert_not_includes payload.to_json, "provider-worker"
  end

  test "private participation cannot serve another organization" do
    @worker.update!(participation_mode: "private")
    job = @application.jobs.create!(task_definition: @definition,
      idempotency_key: "private-provider", input: { text: "Hello" })

    post api_v1_worker_claims_path, headers: worker_headers, as: :json

    assert_nil response.parsed_body["job"]
    assert_equal "queued", job.reload.status
  end

  test "consumer owner and organization trust do not accept external capacity" do
    @application.update!(minimum_worker_trust: "owner")
    job = @application.jobs.create!(task_definition: @definition,
      idempotency_key: "consumer-owner-trust", input: { text: "Hello" })

    post api_v1_worker_claims_path, headers: worker_headers, as: :json

    assert_nil response.parsed_body["job"]
    assert_equal "queued", job.reload.status
  end

  test "revoking a grant stops queued cross-organization work without broadening routing" do
    job = @application.jobs.create!(task_definition: @definition,
      idempotency_key: "revoked-grant", input: { text: "Hello" })
    @pool.worker_pool_access_grants.find_by!(organization: @consumer).destroy!

    post api_v1_worker_claims_path, headers: worker_headers, as: :json

    assert_nil response.parsed_body["job"]
    assert_equal @pool, job.reload.worker_pool
    assert_equal "Shared GPU", job.routing_pool_name
    assert_nil @application.reload.worker_pool
  end

  test "workers cannot fetch an unleased consumer definition" do
    get api_v1_worker_task_definition_path(@definition.digest), headers: worker_headers

    assert_response :not_found
  end
end

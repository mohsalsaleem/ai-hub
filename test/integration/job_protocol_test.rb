require "test_helper"
require "base64"

class JobProtocolTest < ActionDispatch::IntegrationTest
  setup do
    @organization = organizations(:one)
    @application, @application_token = HubApplication.issue!(organization: @organization, name: "Sums", slug: "sums")
    @worker, @worker_token = Worker.issue!(organization: @organization, name: "Home worker")
    @definition = @application.task_definitions.create!(
      key: "sums.extract", version: 1, instructions: "Extract the title.",
      input_schema: { type: "object", required: [ "text" ], properties: { text: { type: "string" } } },
      output_schema: { type: "object", required: [ "title" ], properties: { title: { type: "string" } } }
    )
  end

  def application_headers = { "Authorization" => "Bearer #{@application_token}" }
  def worker_headers
    { "Authorization" => "Bearer #{@worker_token}", "X-Worker-Id" => "test-worker",
      "X-Worker-Capabilities" => "structured_generation" }
  end

  def enroll_worker
    @worker_key = OpenSSL::PKey.generate_key("ED25519")
    fingerprint = OpenSSL::Digest::SHA256.hexdigest(@worker_key.public_to_der)
    proof = @worker_key.sign(nil, "aihub-worker-enrollment/v1\n#{fingerprint}")
    post api_v1_worker_enroll_path, headers: { "Authorization" => "Bearer #{@worker_token}" }, as: :json,
      params: { public_key: @worker_key.public_to_pem, proof: Base64.strict_encode64(proof) }
    assert_response :success
    fingerprint
  end

  def signed_worker_headers(path:, body:, nonce: SecureRandom.hex(24), timestamp: Time.current.to_i.to_s)
    fingerprint = @worker.reload.key_fingerprint
    canonical = WorkerRequestSignature.canonical(method: "POST", path:, timestamp:, nonce:, body:)
    { "Content-Type" => "application/json", "X-Worker-Key-Id" => fingerprint,
      "X-Worker-Timestamp" => timestamp, "X-Worker-Nonce" => nonce,
      "X-Worker-Signature" => Base64.strict_encode64(@worker_key.sign(nil, canonical)),
      "X-Worker-Id" => "test-worker", "X-Worker-Capabilities" => "structured_generation" }
  end

  test "application submits an idempotent job and reads its state" do
    payload = { task: "sums.extract@1", idempotency_key: "message-42", input: { text: "Hello" } }
    assert_difference "Job.count", 1 do
      post api_v1_jobs_path, params: payload, headers: application_headers, as: :json
      assert_response :created
    end
    job_id = response.parsed_body.fetch("id")

    assert_no_difference "Job.count" do
      post api_v1_jobs_path, params: payload, headers: application_headers, as: :json
      assert_response :success
      assert_equal job_id, response.parsed_body.fetch("id")
    end

    get api_v1_job_path(job_id), headers: application_headers
    assert_equal "queued", response.parsed_body.fetch("status")
    assert response.parsed_body.dig("routing", "code").present?
    assert_not response.parsed_body.to_json.include?(@worker.name)
  end

  test "worker claims, resolves a cached definition, and completes a job" do
    job = @application.jobs.create!(task_definition: @definition, idempotency_key: "one", input: { text: "Hello" })

    post api_v1_worker_claims_path, params: { wait_seconds: 0 }, headers: worker_headers, as: :json
    assert_response :success
    claim = response.parsed_body
    assert_equal job.public_id, claim.dig("job", "id")
    assert_equal @definition.digest, claim.dig("job", "task_digest")
    decision = job.reload.routing_decisions.selected.sole
    assert_equal @worker, decision.worker
    assert_equal true, decision.evidence.dig("checks", "capabilities")

    get api_v1_worker_task_definition_path(@definition.digest), headers: worker_headers
    assert_response :success
    assert_equal "Extract the title.", response.parsed_body.fetch("instructions")

    post api_v1_worker_job_complete_path(job.public_id), headers: worker_headers, as: :json,
      params: { lease_token: claim.fetch("lease_token"), output: { title: "Hello" } }
    assert_response :success
    assert_equal({ "title" => "Hello" }, job.reload.output)
    assert_equal "completed", job.status

    post api_v1_worker_job_complete_path(job.public_id), headers: worker_headers, as: :json,
      params: { lease_token: claim.fetch("lease_token"), output: { title: "Hello" } }
    assert_response :success
    assert_equal "completed", response.parsed_body.fetch("status")
  end

  test "stale leases and schema-invalid output are rejected" do
    job = @application.jobs.create!(task_definition: @definition, idempotency_key: "two", input: { text: "Hello" })
    post api_v1_worker_claims_path, headers: worker_headers, as: :json
    lease = response.parsed_body.fetch("lease_token")

    post api_v1_worker_job_complete_path(job.public_id), headers: worker_headers, as: :json,
      params: { lease_token: "wrong", output: { title: "Hello" } }
    assert_response :conflict

    post api_v1_worker_job_complete_path(job.public_id), headers: worker_headers, as: :json,
      params: { lease_token: lease, output: { wrong: true } }
    assert_response :unprocessable_entity
    assert_equal "leased", job.reload.status
  end

  test "an expired final lease becomes dead without another selection record" do
    job = @application.jobs.create!(task_definition: @definition, idempotency_key: "last-attempt",
      input: { text: "Hello" }, max_attempts: 1)
    post api_v1_worker_claims_path, headers: worker_headers, as: :json
    assert_equal job.public_id, response.parsed_body.dig("job", "id")

    travel Job::LEASE_SECONDS.seconds + 1.second do
      post api_v1_worker_claims_path, headers: worker_headers, as: :json
      assert_nil response.parsed_body["job"]
    end

    assert_equal "dead", job.reload.status
    assert_equal "lease_expired", job.error.fetch("code")
    assert_equal 2, job.routing_decisions.count
  end

  test "retryable failures return jobs to the queue with backoff" do
    job = @application.jobs.create!(task_definition: @definition, idempotency_key: "three", input: { text: "Hello" })
    post api_v1_worker_claims_path, headers: worker_headers, as: :json
    lease = response.parsed_body.fetch("lease_token")

    post api_v1_worker_job_fail_path(job.public_id), headers: worker_headers, as: :json,
      params: { lease_token: lease, error: { code: "model_offline", message: "Unavailable", retryable: true } }
    assert_response :success
    assert_equal "queued", job.reload.status
    assert job.available_at.future?
  end

  test "tokens are scoped by actor type and application" do
    post api_v1_jobs_path, params: {}, headers: worker_headers, as: :json
    assert_response :unauthorized

    post api_v1_worker_claims_path, params: {}, headers: application_headers, as: :json
    assert_response :unauthorized

    other, token = HubApplication.issue!(organization: organizations(:two), name: "Other", slug: "other")
    get api_v1_job_path(@application.jobs.create!(task_definition: @definition,
      idempotency_key: "private", input: { text: "x" }).public_id), headers: { "Authorization" => "Bearer #{token}" }
    assert_response :not_found
    assert other.active?
  end

  test "application registers immutable task versions" do
    post api_v1_task_definitions_path, headers: application_headers, as: :json, params: {
      task_definition: { key: "sums.summarize", version: 1, executor: "structured_generation",
        instructions: "Summarize.", input_schema: { type: "object" }, output_schema: { type: "object" } }
    }
    assert_response :created
    assert_match(/\A[0-9a-f]{64}\z/, response.parsed_body.fetch("digest"))

    post api_v1_task_definitions_path, headers: application_headers, as: :json, params: {
      task_definition: { key: "sums.summarize", version: 1, instructions: "Changed.",
        input_schema: { type: "object" }, output_schema: { type: "object" } }
    }
    assert_response :unprocessable_entity
  end

  test "chat definitions receive the OpenAI-compatible schemas by default" do
    post api_v1_task_definitions_path, headers: application_headers, as: :json, params: {
      task_definition: { key: "assistant.general", version: 1, executor: "chat_completion",
        instructions: "Answer clearly." }
    }

    assert_response :created
    definition = @application.task_definitions.find_by!(key: "assistant.general")
    assert_equal TaskDefinition::CHAT_INPUT_SCHEMA.deep_stringify_keys, definition.input_schema
    assert_equal TaskDefinition::CHAT_OUTPUT_SCHEMA.deep_stringify_keys, definition.output_schema
  end

  test "workers only claim jobs matching advertised capabilities" do
    vision = @application.task_definitions.create!(key: "sums.vision", version: 1, instructions: "Read image",
      requirements: { "vision" => true }, input_schema: { type: "object" }, output_schema: { type: "object" })
    @application.jobs.create!(task_definition: vision, idempotency_key: "vision", input: {})

    post api_v1_worker_claims_path, headers: worker_headers, as: :json
    assert_response :success
    assert_nil response.parsed_body["job"]
  end

  test "workers never claim another organization's compatible jobs" do
    other_application, = HubApplication.issue!(organization: organizations(:two), name: "Other", slug: "other")
    definition = other_application.task_definitions.create!(key: "other.task", version: 1,
      instructions: "Summarize.", input_schema: { type: "object" }, output_schema: { type: "object" })
    other_application.jobs.create!(task_definition: definition, idempotency_key: "tenant-boundary", input: {})

    post api_v1_worker_claims_path, headers: worker_headers, as: :json

    assert_response :success
    assert_nil response.parsed_body["job"]
  end

  test "applications must opt in to lower-trust workers" do
    @worker.update!(trust_tier: "verified")
    job = @application.jobs.create!(task_definition: @definition,
      idempotency_key: "trust-boundary", input: { text: "Private" })

    post api_v1_worker_claims_path, params: { wait_seconds: 0 }, headers: worker_headers, as: :json
    assert_response :success
    assert_nil response.parsed_body["job"]

    @application.update!(minimum_worker_trust: "verified")
    eligible_job = @application.jobs.create!(task_definition: @definition,
      idempotency_key: "lower-trust-opt-in", input: { text: "Allowed" })
    post api_v1_worker_claims_path, params: { wait_seconds: 0 }, headers: worker_headers, as: :json
    assert_equal eligible_job.public_id, response.parsed_body.dig("job", "id")
    assert_equal "owner", job.reload.minimum_worker_trust
  end

  test "worker pools restrict claims after trust checks pass" do
    allowed_pool = @organization.worker_pools.create!(name: "Private GPU")
    @application.update!(worker_pool: allowed_pool)
    job = @application.jobs.create!(task_definition: @definition,
      idempotency_key: "pool-boundary", input: { text: "Private" })

    post api_v1_worker_claims_path, params: { wait_seconds: 0 }, headers: worker_headers, as: :json
    assert_response :success
    assert_nil response.parsed_body["job"]

    @worker.worker_pools << allowed_pool
    post api_v1_worker_claims_path, params: { wait_seconds: 0 }, headers: worker_headers, as: :json
    assert_equal job.public_id, response.parsed_body.dig("job", "id")
    assert_equal allowed_pool, job.reload.worker_pool
  end

  test "application routing changes do not alter queued runs" do
    original_pool = @organization.worker_pools.create!(name: "Original pool")
    replacement_pool = @organization.worker_pools.create!(name: "Replacement pool")
    @worker.worker_pools << original_pool
    @application.update!(worker_pool: original_pool)
    job = @application.jobs.create!(task_definition: @definition,
      idempotency_key: "routing-snapshot", input: { text: "Private" })

    @application.update!(worker_pool: replacement_pool)
    post api_v1_worker_claims_path, params: { wait_seconds: 0 }, headers: worker_headers, as: :json

    assert_equal job.public_id, response.parsed_body.dig("job", "id")
    assert_equal original_pool, job.reload.worker_pool
    assert_equal %w[queued selected], job.routing_decisions.order(:created_at).pluck(:outcome)
  end

  test "removing a pool does not broaden its queued runs to automatic routing" do
    pool = @organization.worker_pools.create!(name: "Temporary pool")
    @application.update!(worker_pool: pool)
    job = @application.jobs.create!(task_definition: @definition,
      idempotency_key: "removed-pool", input: { text: "Private" })

    pool.destroy!
    post api_v1_worker_claims_path, params: { wait_seconds: 0 }, headers: worker_headers, as: :json

    assert_nil response.parsed_body["job"]
    assert_nil job.reload.worker_pool_id
    assert_equal "Temporary pool", job.routing_pool_name
    assert_equal "no_capacity", RoutingDiagnosis.new(job).call.code
  end

  test "enrolled workers require signed requests" do
    fingerprint = enroll_worker
    assert_equal fingerprint, @worker.reload.key_fingerprint
    assert @worker.worker_enrollment_grants.first.used_at.present?
    assert_equal %w[grant_issued enrolled], @worker.worker_identity_events.order(:created_at).pluck(:event_type)

    post api_v1_worker_enroll_path, headers: { "Authorization" => "Bearer #{@worker_token}" }, as: :json,
      params: { public_key: @worker_key.public_to_pem, proof: "unused" }
    assert_response :unauthorized

    post api_v1_worker_claims_path, params: { wait_seconds: 0 }, headers: worker_headers, as: :json
    assert_response :unauthorized

    body = JSON.generate(wait_seconds: 0)
    headers = signed_worker_headers(path: api_v1_worker_claims_path, body:)
    post api_v1_worker_claims_path, params: body, headers: headers
    assert_response :success
  end

  test "signed worker requests cannot be replayed" do
    enroll_worker
    body = JSON.generate(wait_seconds: 0)
    headers = signed_worker_headers(path: api_v1_worker_claims_path, body:)

    post api_v1_worker_claims_path, params: body, headers: headers
    assert_response :success
    post api_v1_worker_claims_path, params: body, headers: headers
    assert_response :conflict
    assert_equal "replayed_request", response.parsed_body.fetch("error")
  end

  test "signed worker requests reject stale timestamps and altered bodies" do
    enroll_worker

    stale_body = JSON.generate(wait_seconds: 0)
    stale_headers = signed_worker_headers(path: api_v1_worker_claims_path, body: stale_body,
      timestamp: 10.minutes.ago.to_i.to_s)
    post api_v1_worker_claims_path, params: stale_body, headers: stale_headers
    assert_response :unauthorized

    signed_body = JSON.generate(wait_seconds: 0)
    altered_body = JSON.generate(wait_seconds: 1)
    altered_headers = signed_worker_headers(path: api_v1_worker_claims_path, body: signed_body)
    post api_v1_worker_claims_path, params: altered_body, headers: altered_headers
    assert_response :unauthorized
  end

  test "rotating a worker token clears its enrolled identity" do
    enroll_worker

    new_token = @worker.reload.rotate_token!

    assert_not @worker.reload.enrolled?
    assert_nil @worker.key_fingerprint
    assert Worker.authenticate(new_token)
    assert WorkerEnrollmentGrant.authenticate(new_token)
    assert_equal "identity_reset", @worker.worker_identity_events.order(:created_at).last.event_type
  end
end

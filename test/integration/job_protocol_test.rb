require "test_helper"

class JobProtocolTest < ActionDispatch::IntegrationTest
  setup do
    @application, @application_token = HubApplication.issue!(name: "Sums", slug: "sums")
    @worker, @worker_token = Worker.issue!(name: "Home worker")
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
  end

  test "worker claims, resolves a cached definition, and completes a job" do
    job = @application.jobs.create!(task_definition: @definition, idempotency_key: "one", input: { text: "Hello" })

    post api_v1_worker_claims_path, params: { wait_seconds: 0 }, headers: worker_headers, as: :json
    assert_response :success
    claim = response.parsed_body
    assert_equal job.public_id, claim.dig("job", "id")
    assert_equal @definition.digest, claim.dig("job", "task_digest")

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

    other, token = HubApplication.issue!(name: "Other", slug: "other")
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

  test "workers only claim jobs matching advertised capabilities" do
    vision = @application.task_definitions.create!(key: "sums.vision", version: 1, instructions: "Read image",
      requirements: { "vision" => true }, input_schema: { type: "object" }, output_schema: { type: "object" })
    @application.jobs.create!(task_definition: vision, idempotency_key: "vision", input: {})

    post api_v1_worker_claims_path, headers: worker_headers, as: :json
    assert_response :success
    assert_nil response.parsed_body["job"]
  end
end

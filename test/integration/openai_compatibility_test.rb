require "test_helper"

class OpenaiCompatibilityTest < ActionDispatch::IntegrationTest
  setup do
    @application, @token = HubApplication.issue!(organization: organizations(:one), name: "Chat app", slug: "chat-app")
    @definition = @application.task_definitions.create!(
      key: "assistant.general", version: 1, executor: "chat_completion", instructions: "Be concise."
    )
  end

  def headers = { "Authorization" => "Bearer #{@token}" }

  test "preserves a strict response schema in the queued job" do
    format = { type: "json_schema", json_schema: { name: "resume", strict: true,
      schema: { type: "object", additionalProperties: false, required: [ "name" ],
        properties: { name: { type: "string" } } } } }
    post "/v1/responses", headers: headers, as: :json,
      params: { model: @definition.reference, input: "Synthetic resume", background: true, response_format: format, presence_penalty: 1.5 }
    assert_response :success
    assert_equal format.deep_stringify_keys, @application.jobs.last.input.fetch("response_format")
    assert_equal 1.5, @application.jobs.last.input.fetch("presence_penalty")
  end

  test "rejects invalid response formats instead of silently dropping them" do
    assert_no_difference "Job.count" do
      post "/v1/responses", headers: headers, as: :json,
        params: { model: @definition.reference, input: "Synthetic", background: true,
          response_format: { type: "unsupported" } }
      assert_response :unprocessable_entity
    end
  end

  test "chat completions expose prompt and completion usage fields" do
    input = { "messages" => [ { "role" => "user", "content" => "Hello" } ] }
    @application.jobs.create!(task_definition: @definition, idempotency_key: "completed-chat",
      input: input, status: "completed", completed_at: Time.current,
      output: { "content" => "{}", "finish_reason" => "stop",
        "usage" => { "prompt_tokens" => 12, "completion_tokens" => 4, "total_tokens" => 16 } })
    post "/v1/chat/completions", headers: headers.merge("Idempotency-Key" => "completed-chat"), as: :json,
      params: { model: @definition.reference, messages: input.fetch("messages") }
    assert_response :success
    assert_equal({ "prompt_tokens" => 12, "completion_tokens" => 4, "total_tokens" => 16 },
      response.parsed_body.fetch("usage"))
  end

  test "lists chat task definitions as models" do
    @application.task_definitions.create!(key: "private.extract", version: 1, instructions: "Extract.",
      input_schema: { type: "object" }, output_schema: { type: "object" })

    get "/v1/models", headers: headers

    assert_response :success
    assert_equal [ "assistant.general@1" ], response.parsed_body.fetch("data").pluck("id")
  end

  test "archived chat definitions are unavailable to new requests" do
    @definition.update!(active: false)

    get "/v1/models", headers: headers
    assert_response :success
    assert_empty response.parsed_body.fetch("data")

    post "/v1/responses", headers: headers, as: :json,
      params: { model: @definition.reference, input: "Hello", background: true }
    assert_response :not_found
    assert_equal 0, @application.jobs.count
  end

  test "creates and retrieves a background response" do
    post "/v1/responses", headers: headers, as: :json,
      params: { model: "assistant.general", input: "Hello", background: true }

    assert_response :success
    response_id = response.parsed_body.fetch("id")
    job = @application.jobs.find_by!(public_id: response_id)
    assert_equal [ { "role" => "user", "content" => "Hello" } ], job.input.fetch("messages")

    worker, = Worker.issue!(organization: organizations(:one), name: "Local")
    job.update!(status: "leased", attempts: 1, worker:, leased_until: 1.minute.from_now,
      lease_token_digest: Job.token_digest("lease"))
    JobExecution.start_for!(job:, worker:).finalize!(outcome: "completed", usage: UsageReport.normalize(
      input_tokens: 3, output_tokens: 2, total_tokens: 99, duration_ms: 20
    ))
    job.update!(status: "completed", output: {
      "content" => "Hi", "finish_reason" => "stop", "usage" => { "total_tokens" => 99 }
    }, completed_at: Time.current)
    get "/v1/responses/#{response_id}", headers: headers

    assert_response :success
    assert_equal "completed", response.parsed_body.fetch("status")
    assert_equal "Hi", response.parsed_body.fetch("output_text")
    assert_equal 5, response.parsed_body.dig("usage", "total_tokens")
  end

  test "reuses an OpenAI request with the same idempotency key" do
    request_headers = headers.merge("Idempotency-Key" => "conversation-turn-1")
    payload = { model: "assistant.general", input: "Hello", background: true }

    assert_difference "Job.count", 1 do
      post "/v1/responses", headers: request_headers, as: :json, params: payload
      assert_response :success
    end
    first_id = response.parsed_body.fetch("id")

    assert_no_difference "Job.count" do
      post "/v1/responses", headers: request_headers, as: :json, params: payload
      assert_response :success
    end
    assert_equal first_id, response.parsed_body.fetch("id")
  end

  test "rejects task definitions belonging to another application" do
    other, = HubApplication.issue!(organization: organizations(:one), name: "Other", slug: "other-chat")
    other.task_definitions.create!(key: "other.general", version: 1, executor: "chat_completion", instructions: "Answer.")

    post "/v1/responses", headers: headers, as: :json,
      params: { model: "other.general", input: "Hello", background: true }

    assert_response :not_found
    assert_equal 0, @application.jobs.count
  end

  test "requires an application token" do
    get "/v1/models"

    assert_response :unauthorized
    assert_equal "invalid_api_key", response.parsed_body.dig("error", "code")
  end

  test "chat completions reject streaming until SSE support is added" do
    post "/v1/chat/completions", headers: headers, as: :json,
      params: { model: @definition.reference, messages: [ { role: "user", content: "Hello" } ], stream: true }

    assert_response :unprocessable_entity
    assert_equal "unsupported_parameter", response.parsed_body.dig("error", "code")
  end
end

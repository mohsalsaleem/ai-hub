require "test_helper"
require_relative "../../worker/lib/ai_hub_worker"

class ExecutorTest < ActiveSupport::TestCase
  FakeResponse = Data.define(:code, :body)

  test "executes an application definition through an OpenAI-compatible model" do
    config = AiHubWorker::Config.new(hub_url: "http://hub", worker_token: "token", worker_id: "worker",
      model_url: "http://model.test/v1", model: "private-model", model_api_key: "local",
      state_path: "/tmp/state", poll_wait_seconds: 0)
    captured = nil
    transport = lambda do |request, uri|
      captured = [ JSON.parse(request.body), uri ]
      FakeResponse.new("200", JSON.generate(choices: [ { message: { content: '{"summary":"Short"}' } } ]))
    end
    executor = AiHubWorker::Executor.new(config, transport:)
    definition = {
      "key" => "example.summarize", "executor" => "structured_generation", "instructions" => "Summarize.",
      "input_schema" => { "type" => "object", "required" => [ "text" ] },
      "output_schema" => { "type" => "object", "required" => [ "summary" ] }
    }

    result = executor.execute(definition, { "text" => "Long" })
    assert_equal({ "summary" => "Short" }, result.output)
    assert_equal "private-model", result.usage.fetch(:llm_model)
    assert_operator result.usage.fetch(:duration_ms), :>=, 0
    assert_equal "/v1/chat/completions", captured[1].path
    assert_equal "private-model", captured[0].fetch("model")
    assert_equal true, captured[0].dig("response_format", "json_schema", "strict")
  end

  test "rejects output outside the registered schema" do
    config = AiHubWorker::Config.new(hub_url: "http://hub", worker_token: "token", worker_id: "worker",
      model_url: "http://model.test/v1", model: "model", model_api_key: "local", state_path: "/tmp", poll_wait_seconds: 0)
    response = FakeResponse.new("200", JSON.generate(choices: [ { message: { content: "{}" } } ]))
    executor = AiHubWorker::Executor.new(config, transport: ->(*) { response })
    definition = { "key" => "app.task", "executor" => "structured_generation", "instructions" => "Do it",
      "input_schema" => { "type" => "object" },
      "output_schema" => { "type" => "object", "required" => [ "answer" ] } }

    assert_raises(AiHubWorker::Executor::Error) { executor.execute(definition, {}) }
  end

  test "executes a chat completion definition without structured output" do
    config = AiHubWorker::Config.new(hub_url: "http://hub", worker_token: "token", worker_id: "worker",
      model_url: "http://model.test/v1", model: "local-chat", model_api_key: "local",
      state_path: "/tmp/state", poll_wait_seconds: 0)
    captured = nil
    response = FakeResponse.new("200", JSON.generate(
      choices: [ { message: { content: "Hello there" }, finish_reason: "stop" } ],
      usage: { prompt_tokens: 2, completion_tokens: 2, total_tokens: 4 }
    ))
    executor = AiHubWorker::Executor.new(config, transport: lambda { |request, _uri|
      captured = JSON.parse(request.body)
      response
    })
    definition = {
      "key" => "assistant.general", "executor" => "chat_completion", "instructions" => "Be concise.",
      "input_schema" => TaskDefinition::CHAT_INPUT_SCHEMA.deep_stringify_keys,
      "output_schema" => TaskDefinition::CHAT_OUTPUT_SCHEMA.deep_stringify_keys
    }

    result = executor.execute(definition, { "messages" => [ { "role" => "user", "content" => "Hi" } ] })

    assert_equal "Hello there", result.output.fetch("content")
    assert_equal 2, result.usage.fetch(:input_tokens)
    assert_equal 2, result.usage.fetch(:output_tokens)
    assert_equal 4, result.usage.fetch(:total_tokens)
    assert_equal "local-chat", captured.fetch("model")
    assert_equal "Be concise.", captured.fetch("messages").first.fetch("content")
    assert_nil captured["response_format"]
  end

  test "attaches measured usage metadata to a model failure" do
    config = AiHubWorker::Config.new(hub_url: "http://hub", worker_token: "token", worker_id: "worker",
      model_url: "http://model.test/v1", model: "local-model", model_api_key: "local",
      state_path: "/tmp/state", poll_wait_seconds: 0)
    response = FakeResponse.new("503", "{}")
    executor = AiHubWorker::Executor.new(config, transport: ->(*) { response })
    definition = {
      "key" => "example.failure", "executor" => "structured_generation", "instructions" => "Generate.",
      "input_schema" => { "type" => "object" }, "output_schema" => { "type" => "object" }
    }

    error = assert_raises(AiHubWorker::Executor::Error) { executor.execute(definition, {}) }

    assert_equal "local-model", error.usage.fetch(:llm_model)
    assert_operator error.usage.fetch(:duration_ms), :>=, 0
    assert_nil error.usage[:total_tokens]
  end
end

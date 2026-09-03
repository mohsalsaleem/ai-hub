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

    assert_equal({ "summary" => "Short" }, executor.execute(definition, { "text" => "Long" }))
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
end

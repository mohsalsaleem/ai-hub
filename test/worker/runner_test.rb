require "test_helper"
require_relative "../../worker/lib/ai_hub_worker"

class RunnerTest < ActiveSupport::TestCase
  FakeCache = Struct.new(:definition) do
    def fetch(*) = definition || yield
  end

  class FakeClient
    def definition(*) = { "executor" => "structured_generation" }
  end

  class FakeOutbox
    attr_reader :rows

    def initialize = @rows = []
    def enqueue(**attributes) = @rows << attributes
  end

  test "queues output and usage together" do
    result = AiHubWorker::Executor::Result.new(output: { "answer" => "yes" },
      usage: { schema_version: 1, llm_model: "local", total_tokens: 4, duration_ms: 12 })
    executor = Struct.new(:result, :model_name) do
      def execute(*) = result
    end.new(result, "local")
    outbox = FakeOutbox.new
    runner = build_runner(executor:, outbox:)

    runner.send(:process, job, "lease")

    payload = outbox.rows.sole.fetch(:payload)
    assert_equal({ "answer" => "yes" }, payload.fetch(:output))
    assert_equal 4, payload.dig(:usage, :total_tokens)
  end

  test "does not invent model usage when execution fails before a model call" do
    executor = Struct.new(:model_name) do
      def execute(*) = raise("model failed")
    end.new("local")
    outbox = FakeOutbox.new
    runner = build_runner(executor:, outbox:)

    runner.send(:process, job, "lease")

    payload = outbox.rows.sole.fetch(:payload)
    assert_equal "execution_failed", payload.dig(:error, :code)
    assert_nil payload[:usage]
  end

  private

  def build_runner(executor:, outbox:)
    AiHubWorker::Runner.new(client: FakeClient.new, executor:, cache: FakeCache.new,
      outbox:, poll_wait_seconds: 0).tap do |runner|
      runner.define_singleton_method(:start_lease_renewer) { |*| nil }
    end
  end

  def job
    { "id" => "job_1", "task_digest" => "digest", "input" => {} }
  end
end

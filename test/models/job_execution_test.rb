require "test_helper"

class JobExecutionTest < ActiveSupport::TestCase
  setup do
    @organization = organizations(:one)
    @application, = HubApplication.issue!(organization: @organization, name: "Metered app", slug: "metered-app")
    @definition = @application.task_definitions.create!(key: "metered.task", version: 1,
      instructions: "Do it.", input_schema: { type: "object" }, output_schema: { type: "object" })
    @worker, = Worker.issue!(organization: @organization, name: "Local worker")
    @job = @application.jobs.create!(task_definition: @definition, idempotency_key: "metered", input: {})
    @job.update!(attempts: 1, status: "leased", worker: @worker,
      leased_until: Job::LEASE_SECONDS.seconds.from_now, lease_token_digest: Job.token_digest("lease"))
    @execution = JobExecution.start_for!(job: @job, worker: @worker)
  end

  test "snapshots accounting identities when an attempt starts" do
    @organization.update!(name: "Renamed organization")
    @application.update!(name: "Renamed app")
    @worker.update!(name: "Renamed worker")

    @execution.reload
    assert_equal "First organization", @execution.consumer_organization_name
    assert_equal "First organization", @execution.provider_organization_name
    assert_equal "Metered app", @execution.application_name
    assert_equal "Local worker", @execution.worker_name
    assert_equal "metered.task@1", @execution.task_reference
  end

  test "finalization canonicalizes token aliases and becomes immutable" do
    @execution.finalize!(outcome: "completed", usage: UsageReport.normalize({
      prompt_tokens: 5, completion_tokens: 4, total_tokens: 500, model: "local", duration_ms: 10
    }))

    assert_equal 5, @execution.input_tokens
    assert_equal 4, @execution.output_tokens
    assert_equal 9, @execution.total_tokens
    assert_equal "local", @execution.llm_model
    assert_raises(ActiveRecord::RecordNotSaved) { @execution.update!(failure_code: "tampered") }
    assert_raises(ActiveRecord::RecordNotDestroyed) { @execution.destroy! }
  end

  test "unreported usage still records the outcome and hub timing" do
    @execution.finalize!(outcome: "failed", failure_code: "model_offline")

    assert_not @execution.usage_reported?
    assert_nil @execution.total_tokens
    assert_equal "model_offline", @execution.failure_code
    assert_operator @execution.hub_duration_ms, :>=, 0
  end

  test "rejects unsupported, negative, and oversized usage" do
    assert_raises(UsageReport::Invalid) { UsageReport.normalize(schema_version: 2) }
    assert_raises(UsageReport::Invalid) { UsageReport.normalize(total_tokens: -1) }
    assert_raises(UsageReport::Invalid) do
      UsageReport.normalize(duration_ms: UsageReport::MAX_DURATION_MS + 1)
    end
    assert_raises(UsageReport::Invalid) do
      UsageReport.normalize(input_tokens: UsageReport::MAX_TOKEN_COUNT, output_tokens: 1)
    end
  end
end

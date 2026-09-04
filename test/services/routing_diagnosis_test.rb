require "test_helper"

class RoutingDiagnosisTest < ActiveSupport::TestCase
  setup do
    @organization = organizations(:one)
    @application, = HubApplication.issue!(organization: @organization, name: "App", slug: "routing-app")
    @definition = @application.task_definitions.create!(key: "app.task", version: 1, instructions: "Do it",
      input_schema: { type: "object" }, output_schema: { type: "object" })
  end

  test "explains when a configured pool has no capacity" do
    pool = @organization.worker_pools.create!(name: "Private GPU")
    @application.update!(worker_pool: pool)
    job = @application.jobs.create!(task_definition: @definition, idempotency_key: "empty", input: {})

    diagnosis = RoutingDiagnosis.new(job).call

    assert_equal "no_capacity", diagnosis.code
  end

  test "explains when compatible capacity is offline" do
    worker, = Worker.issue!(organization: @organization, name: "Home worker",
      capabilities: [ "structured_generation" ])
    job = @application.jobs.create!(task_definition: @definition, idempotency_key: "offline", input: {})

    diagnosis = RoutingDiagnosis.new(job).call

    assert_equal "eligible_capacity_offline", diagnosis.code
    assert_not_includes diagnosis.summary, worker.name
  end

  test "reports a selection without exposing the worker" do
    worker, = Worker.issue!(organization: @organization, name: "Home worker",
      capabilities: [ "structured_generation" ], last_seen_at: Time.current)
    job = @application.jobs.create!(task_definition: @definition, idempotency_key: "selected", input: {})
    job.update!(worker: worker, status: "leased")

    diagnosis = RoutingDiagnosis.new(job).call

    assert_equal "capacity_selected", diagnosis.code
    assert_not_includes diagnosis.summary, worker.name
  end

  test "distinguishes paused and busy compatible capacity" do
    worker, = Worker.issue!(organization: @organization, name: "Home worker",
      capabilities: [ "structured_generation" ], last_seen_at: Time.current, paused_at: Time.current)
    job = @application.jobs.create!(task_definition: @definition, idempotency_key: "waiting", input: {})

    assert_equal "capacity_paused", RoutingDiagnosis.new(job).call.code

    worker.update!(paused_at: nil)
    worker.jobs.create!(hub_application: @application, task_definition: @definition,
      idempotency_key: "active", input: {}, status: "leased", leased_until: 1.minute.from_now)
    assert_equal "capacity_busy", RoutingDiagnosis.new(job).call.code
  end
end

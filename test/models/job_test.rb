require "test_helper"

class JobTest < ActiveSupport::TestCase
  setup do
    application, = HubApplication.issue!(organization: organizations(:one), name: "App", slug: "app")
    @definition = application.task_definitions.create!(key: "app.task", version: 1, instructions: "Do it",
      input_schema: { type: "object", required: [ "name" ] }, output_schema: { type: "object" })
    @application = application
  end

  test "validates input against the registered schema" do
    job = @application.jobs.new(task_definition: @definition, idempotency_key: "bad", input: {})
    assert_not job.valid?
    assert_includes job.errors[:input], "does not match task schema"
  end

  test "assigns opaque public id and availability" do
    job = @application.jobs.create!(task_definition: @definition, idempotency_key: "good", input: { name: "A" })
    assert_match(/\Ajob_[0-9a-f]{24}\z/, job.public_id)
    assert job.available_at.present?
    assert_equal "awaiting_eligible_capacity", job.routing_decisions.sole.reason
  end

  test "snapshots the application routing policy" do
    pool = organizations(:one).worker_pools.create!(name: "Private GPU")
    @application.update!(worker_pool: pool, minimum_worker_trust: "verified")

    job = @application.jobs.create!(task_definition: @definition, idempotency_key: "routed", input: { name: "A" })
    @application.update!(worker_pool: nil, minimum_worker_trust: "external")

    assert_equal pool, job.reload.worker_pool
    assert_equal "Private GPU", job.routing_pool_name
    assert_equal "verified", job.minimum_worker_trust
    assert_equal [ "structured_generation" ], job.routing_decisions.sole.evidence.fetch("required_capabilities")
  end

  test "allows identical task contracts in separate organizations" do
    other_application, = HubApplication.issue!(organization: organizations(:two), name: "Other", slug: "other")
    other_definition = other_application.task_definitions.create!(
      key: @definition.key,
      version: @definition.version,
      executor: @definition.executor,
      instructions: @definition.instructions,
      input_schema: @definition.input_schema,
      output_schema: @definition.output_schema,
      requirements: @definition.requirements
    )

    assert_equal @definition.digest, other_definition.digest
  end
end

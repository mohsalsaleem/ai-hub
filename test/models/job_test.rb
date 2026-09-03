require "test_helper"

class JobTest < ActiveSupport::TestCase
  setup do
    application, = HubApplication.issue!(name: "App", slug: "app")
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
  end
end

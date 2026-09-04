require "test_helper"

class WorkerTest < ActiveSupport::TestCase
  setup do
    @organization = organizations(:one)
    @worker, = Worker.issue!(organization: @organization, name: "Home worker",
      capabilities: [ "structured_generation" ], last_seen_at: Time.current)
  end

  test "new workers default to private always-available capacity" do
    assert_equal "private", @worker.participation_mode
    assert_equal Worker::AVAILABILITY_DAYS, @worker.availability_days
    assert @worker.accepting_jobs?
    assert_equal "available", @worker.participation_state
  end

  test "manual pause stops claims without making the worker offline" do
    @worker.update!(paused_at: Time.current)

    assert_not @worker.accepting_jobs?
    assert_equal "paused", @worker.participation_state
    assert @worker.online?
  end

  test "overnight availability uses the day on which the window starts" do
    @worker.update!(availability_timezone: "UTC", availability_days: [ "monday" ],
      availability_starts_at: "22:00", availability_ends_at: "06:00")

    assert @worker.scheduled_available_at?(Time.utc(2026, 9, 7, 23, 0))
    assert @worker.scheduled_available_at?(Time.utc(2026, 9, 8, 1, 0))
    assert_not @worker.scheduled_available_at?(Time.utc(2026, 9, 8, 7, 0))
  end

  test "concurrency limits active leases" do
    application, = HubApplication.issue!(organization: @organization, name: "App", slug: "capacity-app")
    definition = application.task_definitions.create!(key: "app.task", version: 1, instructions: "Do it",
      input_schema: { type: "object" }, output_schema: { type: "object" })
    application.jobs.create!(task_definition: definition, idempotency_key: "active", input: {},
      worker: @worker, status: "leased", leased_until: 1.minute.from_now)

    assert_not @worker.accepting_jobs?
    assert_equal "busy", @worker.participation_state

    @worker.update!(max_concurrent_jobs: 2)
    assert @worker.accepting_jobs?
  end

  test "availability policy validates days, times, and concurrency" do
    @worker.assign_attributes(availability_days: [ "noday" ], availability_starts_at: "25:00",
      availability_ends_at: "06:00", max_concurrent_jobs: 0)

    assert_not @worker.valid?
    assert @worker.errors[:availability_days].any?
    assert @worker.errors[:availability_starts_at].any?
    assert @worker.errors[:max_concurrent_jobs].any?
  end
end

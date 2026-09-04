require "test_helper"

class CreditLedgerEntryTest < ActiveSupport::TestCase
  setup do
    @consumer = organizations(:one)
    @provider = organizations(:two)
    application, = HubApplication.issue!(organization: @consumer, name: "Ledger app", slug: "ledger-app")
    definition = application.task_definitions.create!(key: "ledger.task", version: 1,
      instructions: "Do it.", input_schema: { type: "object" }, output_schema: { type: "object" })
    worker, = Worker.issue!(organization: @provider, name: "Provider worker")
    pool = @provider.worker_pools.create!(name: "Shared", slug: "shared-ledger", access_mode: "shared",
      operator_status: "approved")
    pool.workers << worker
    job = application.jobs.create!(task_definition: definition, idempotency_key: "ledger", input: {},
      worker_pool: pool, routing_pool_name: pool.name)
    job.update!(attempts: 1, status: "leased", worker:,
      leased_until: Job::LEASE_SECONDS.seconds.from_now, lease_token_digest: Job.token_digest("lease"))
    @execution = JobExecution.start_for!(job:, worker:)
  end

  test "successful reported shared usage posts a balanced split" do
    @execution.finalize!(outcome: "completed",
      usage: UsageReport.normalize(input_tokens: 80, output_tokens: 20))

    entries = @execution.credit_ledger_entries.index_by(&:entry_type)
    assert_equal(-100, entries.fetch("consumer_debit").amount)
    assert_equal 80, entries.fetch("provider_credit").amount
    assert_equal 20, entries.fetch("platform_credit").amount
    assert LedgerReconciliation.call.balanced
  end

  test "failed and unreported executions are not charged" do
    @execution.finalize!(outcome: "failed", failure_code: "model_offline")

    assert_empty @execution.credit_ledger_entries
  end

  test "small charges remain balanced when the platform share rounds down" do
    @execution.finalize!(outcome: "completed", usage: UsageReport.normalize(total_tokens: 1))

    entries = @execution.credit_ledger_entries.index_by(&:entry_type)
    assert_equal(-1, entries.fetch("consumer_debit").amount)
    assert_equal 1, entries.fetch("provider_credit").amount
    assert_equal 0, entries.fetch("platform_credit").amount
    assert LedgerReconciliation.call.balanced
  end

  test "entries cannot be changed or destroyed" do
    @execution.finalize!(outcome: "completed", usage: UsageReport.normalize(total_tokens: 10))
    entry = @execution.credit_ledger_entries.first

    assert_raises(ActiveRecord::RecordNotSaved) { entry.update!(amount: -20) }
    assert_raises(ActiveRecord::RecordNotDestroyed) { entry.destroy! }
  end

  test "reconciliation reports a billable execution with missing entries" do
    @execution.update!(outcome: "completed", usage_reported: true, total_tokens: 10,
      finished_at: Time.current)

    result = LedgerReconciliation.call
    assert_not result.balanced
    assert_includes result.errors, @execution.id
  end
end

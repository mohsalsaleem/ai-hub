class LedgerReconciliation
  Result = Data.define(:balanced, :execution_count, :entry_count, :net_amount, :errors)

  def self.call(scope = JobExecution.all)
    executions = scope.where(shared: true, outcome: "completed", usage_reported: true)
      .where("total_tokens > 0").includes(:credit_ledger_entries)
    errors = executions.filter_map do |execution|
      entries = execution.credit_ledger_entries
      types = entries.map(&:entry_type).sort
      next if types == CreditLedgerEntry::EXECUTION_ENTRY_TYPES.sort && entries.sum(&:amount).zero?

      execution.id
    end
    entries = CreditLedgerEntry.where(job_execution_id: executions.select(:id))
    net = entries.sum(:amount)
    Result.new(balanced: errors.empty? && net.zero?, execution_count: executions.count,
      entry_count: entries.count, net_amount: net, errors: errors)
  end
end

class ExecutionCharger
  PRICING_VERSION = 1
  PLATFORM_SHARE_PERCENT = 20

  def self.post!(execution)
    return [] unless billable?(execution)

    total = execution.total_tokens
    platform = total * PLATFORM_SHARE_PERCENT / 100
    provider = total - platform
    attributes = [
      { entry_type: "consumer_debit", amount: -total,
        organization: execution.consumer_organization,
        organization_name: execution.consumer_organization_name },
      { entry_type: "provider_credit", amount: provider,
        organization: execution.provider_organization,
        organization_name: execution.provider_organization_name },
      { entry_type: "platform_credit", amount: platform }
    ]

    attributes.map do |entry|
      execution.credit_ledger_entries.create!(entry.merge(pricing_version: PRICING_VERSION))
    end
  end

  def self.billable?(execution)
    execution.finalized? && execution.shared? && execution.outcome == "completed" &&
      execution.usage_reported? && execution.total_tokens.to_i.positive?
  end
  private_class_method :billable?
end

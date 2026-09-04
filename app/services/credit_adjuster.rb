class CreditAdjuster
  def self.post!(organization:, amount:, reason:, operator:, request_ip: nil)
    amount = Integer(amount, 10)
    raise ArgumentError, "Amount cannot be zero" if amount.zero?

    CreditLedgerEntry.transaction do
      entry = CreditLedgerEntry.create!(entry_type: "admin_adjustment", organization:,
        organization_name: organization.name, amount:, pricing_version: ExecutionCharger::PRICING_VERSION,
        platform_operator: operator, reason: reason.to_s.strip)
      operator.platform_audit_events.create!(action: "credits.adjusted", subject_type: "Organization",
        subject_id: organization.id, subject_label: organization.name, request_ip:,
        details: { credit_ledger_entry_id: entry.id, amount:, reason: entry.reason,
                   resulting_balance: organization.credit_balance })
      entry
    end
  rescue ArgumentError, TypeError
    raise ArgumentError, "Amount must be a non-zero whole number"
  end
end

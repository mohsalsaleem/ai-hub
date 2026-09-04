class AddAdminAdjustmentsToCreditLedger < ActiveRecord::Migration[8.1]
  def change
    change_column_null :credit_ledger_entries, :job_execution_id, true
    add_reference :credit_ledger_entries, :platform_operator, null: true, foreign_key: true
    add_column :credit_ledger_entries, :reason, :string
  end
end

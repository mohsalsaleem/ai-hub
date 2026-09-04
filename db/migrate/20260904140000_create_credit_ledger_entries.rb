class CreateCreditLedgerEntries < ActiveRecord::Migration[8.1]
  def change
    create_table :credit_ledger_entries do |t|
      t.references :job_execution, null: false, foreign_key: true
      t.references :organization, null: true, foreign_key: true
      t.string :entry_type, null: false
      t.bigint :amount, null: false
      t.string :unit, default: "internal_credit", null: false
      t.integer :pricing_version, null: false
      t.string :organization_name
      t.timestamps

      t.index [ :job_execution_id, :entry_type ], unique: true
      t.index [ :organization_id, :created_at ]
    end
  end
end

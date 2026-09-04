class AddPlatformOperatorFoundation < ActiveRecord::Migration[8.1]
  def change
    create_table :platform_operators do |t|
      t.string :email_address, null: false
      t.string :password_digest, null: false
      t.boolean :active, default: true, null: false
      t.timestamps

      t.index :email_address, unique: true
    end

    create_table :platform_sessions do |t|
      t.references :platform_operator, null: false, foreign_key: true
      t.string :ip_address
      t.string :user_agent
      t.timestamps
    end

    add_column :worker_pools, :operator_status, :string, default: "not_applicable", null: false
    add_index :worker_pools, :operator_status

    reversible do |direction|
      direction.up do
        execute <<~SQL.squish
          UPDATE worker_pools
          SET operator_status = 'pending_review'
          WHERE access_mode = 'shared'
        SQL
      end
    end

    create_table :platform_audit_events do |t|
      t.references :platform_operator, null: false, foreign_key: true
      t.string :action, null: false
      t.string :subject_type, null: false
      t.integer :subject_id, null: false
      t.string :subject_label, null: false
      t.json :details, default: {}, null: false
      t.string :request_ip
      t.timestamps

      t.index [ :subject_type, :subject_id, :created_at ], name: "index_platform_audits_on_subject"
    end
  end
end

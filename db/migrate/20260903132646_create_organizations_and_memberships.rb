class CreateOrganizationsAndMemberships < ActiveRecord::Migration[8.1]
  class MigrationOrganization < ActiveRecord::Base
    self.table_name = "organizations"
  end

  def up
    create_table :organizations do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.timestamps
      t.index :slug, unique: true
    end

    create_table :memberships do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :role, null: false, default: "member"
      t.timestamps
      t.index [ :organization_id, :user_id ], unique: true
    end

    add_reference :hub_applications, :organization, foreign_key: true
    add_reference :workers, :organization, foreign_key: true
    add_column :hub_applications, :token_hint, :string
    add_column :workers, :token_hint, :string
    remove_index :hub_applications, :slug
    add_index :hub_applications, [ :organization_id, :slug ], unique: true

    if table_has_rows?(:hub_applications) || table_has_rows?(:workers)
      organization = MigrationOrganization.create!(name: "SUMS", slug: "sums")
      execute "UPDATE hub_applications SET organization_id = #{organization.id}"
      execute "UPDATE workers SET organization_id = #{organization.id}"
    end

    change_column_null :hub_applications, :organization_id, false
    change_column_null :workers, :organization_id, false
  end

  def down
    remove_index :hub_applications, [ :organization_id, :slug ]
    add_index :hub_applications, :slug, unique: true
    remove_reference :workers, :organization, foreign_key: true
    remove_reference :hub_applications, :organization, foreign_key: true
    remove_column :workers, :token_hint
    remove_column :hub_applications, :token_hint
    drop_table :memberships
    drop_table :organizations
  end

  private

  def table_has_rows?(table)
    select_value("SELECT 1 FROM #{quote_table_name(table)} LIMIT 1").present?
  end
end

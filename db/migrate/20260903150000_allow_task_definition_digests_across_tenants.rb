class AllowTaskDefinitionDigestsAcrossTenants < ActiveRecord::Migration[8.1]
  def change
    remove_index :task_definitions, :digest
    add_index :task_definitions, :digest
  end
end

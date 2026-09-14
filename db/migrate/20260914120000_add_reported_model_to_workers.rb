class AddReportedModelToWorkers < ActiveRecord::Migration[8.1]
  def change
    add_column :workers, :reported_model, :string
  end
end

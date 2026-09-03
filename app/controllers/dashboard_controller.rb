class DashboardController < ApplicationController
  def show
    @counts = Job.group(:status).count
    @workers = Worker.order(last_seen_at: :desc, created_at: :desc)
    @definitions = TaskDefinition.includes(:hub_application).order(created_at: :desc).limit(10)
    @jobs = Job.includes(:hub_application, :task_definition, :worker).order(created_at: :desc).limit(25)
  end
end

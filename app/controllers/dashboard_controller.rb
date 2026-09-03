class DashboardController < ApplicationController
  def show
    jobs = current_organization.jobs
    recent = jobs.where("jobs.created_at >= ?", 24.hours.ago)
    @counts = jobs.group(:status).count
    @recent_count = recent.count
    @success_rate = @recent_count.zero? ? nil : (recent.where(status: "completed").count.fdiv(@recent_count) * 100)
    @workers = current_organization.workers.order(last_seen_at: :desc, created_at: :desc)
    @applications = current_organization.hub_applications
    @definitions = current_organization.task_definitions
    @jobs = jobs.includes(:hub_application, :task_definition, :worker).order(created_at: :desc).limit(8)
  end
end

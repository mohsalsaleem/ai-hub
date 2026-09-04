class JobsController < ApplicationController
  def index
    @status = params[:status].presence_in(Job::STATUSES)
    @jobs = current_organization.jobs.includes(:hub_application, :task_definition, :worker)
    @jobs = @jobs.where(status: @status) if @status
    @jobs = @jobs.order(created_at: :desc).limit(200)
  end

  def show
    @job = current_organization.jobs
      .includes(:hub_application, :task_definition, :worker_pool, :routing_decisions, :job_executions)
      .find_by!(public_id: params[:id])
    @routing_diagnosis = RoutingDiagnosis.new(@job).call
    @usage_summary = UsageSummary.new(@job.job_executions.select(&:finalized?)).call
  end
end

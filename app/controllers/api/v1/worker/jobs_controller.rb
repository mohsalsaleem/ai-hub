module Api
  module V1
    module Worker
      class JobsController < BaseController
        MAX_RESULT_BYTES = 256.kilobytes

        before_action :load_job
        before_action :verify_lease
        rescue_from UsageReport::Invalid,
          with: ->(error) { render json: { error: "invalid_usage", message: error.message }, status: :unprocessable_entity }

        def renew
          @job.update!(leased_until: Job::LEASE_SECONDS.seconds.from_now)
          render json: { status: "leased", lease_seconds: Job::LEASE_SECONDS }
        end

        def complete
          return render json: { status: "completed" } if @job.status == "completed"
          return render(json: { error: "result_too_large" }, status: :content_too_large) if request.content_length.to_i > MAX_RESULT_BYTES

          output = json_object(:output)
          unless JSONSchemer.schema(@job.task_definition.output_schema).valid?(output)
            return render json: { error: "output_schema_mismatch" }, status: :unprocessable_entity
          end

          usage = UsageReport.normalize(params[:usage])
          @job.transaction do
            current_execution.finalize!(outcome: "completed", usage:, finished_at: Time.current)
            @job.update!(status: "completed", output:, error: nil, completed_at: Time.current,
              leased_until: nil, lease_token_digest: nil)
          end
          render json: { status: "completed" }
        end

        def fail
          error = params.require(:error).permit(:code, :message, :retryable).to_h
          retryable = ActiveModel::Type::Boolean.new.cast(error["retryable"])
          usage = UsageReport.normalize(params[:usage])
          @job.transaction do
            status = if retryable && @job.attempts < @job.max_attempts
              "queued"
            else
              @job.attempts >= @job.max_attempts ? "dead" : "failed"
            end
            current_execution.finalize!(outcome: status == "queued" ? "failed" : status,
              usage:, failure_code: error["code"], finished_at: Time.current)
            attributes = { status:, error:, leased_until: nil, lease_token_digest: nil }
            attributes.merge!(available_at: backoff.from_now, worker: nil) if status == "queued"
            attributes[:completed_at] = Time.current unless status == "queued"
            @job.update!(attributes)
          end
          render json: { status: @job.status }
        end

        private

        def load_job
          @job = current_worker.jobs.find_by!(public_id: params[:job_id])
        rescue ActiveRecord::RecordNotFound
          render json: { error: "unknown_job" }, status: :not_found
        end

        def verify_lease
          return if performed?
          return if action_name == "complete" && @job.status == "completed"
          return if @job.lease_valid?(params[:lease_token])

          render json: { error: "stale_lease" }, status: :conflict
        end

        def current_execution
          @job.job_executions.find_by(attempt_number: @job.attempts, worker: current_worker) ||
            JobExecution.start_for!(job: @job, worker: current_worker, started_at: @job.updated_at)
        end

        def backoff = [ 2**@job.attempts, 300 ].min.seconds

        def json_object(key)
          value = params.require(key)
          raise ActionController::ParameterMissing, key unless value.is_a?(ActionController::Parameters)

          value.to_unsafe_h
        end
      end
    end
  end
end

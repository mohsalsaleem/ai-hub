module Api
  module V1
    class JobsController < ApplicationController
      MAX_PAYLOAD_BYTES = 256.kilobytes

      def create
        return render(json: { error: "input_too_large" }, status: :content_too_large) if request.content_length.to_i > MAX_PAYLOAD_BYTES

        definition = find_definition
        job = hub_application.jobs.find_or_initialize_by(idempotency_key: params.require(:idempotency_key).to_s.first(200))
        if job.new_record?
          job.assign_attributes(task_definition: definition, input: json_object(:input),
            priority: params.fetch(:priority, 0).to_i.clamp(-10, 10), max_attempts: params.fetch(:max_attempts, 5))
          job.save!
        end
        render json: job_json(job), status: job.previously_new_record? ? :created : :ok
      rescue ActiveRecord::RecordInvalid => e
        render json: { error: "invalid_job", details: e.record.errors.full_messages }, status: :unprocessable_entity
      rescue ActiveRecord::RecordNotFound
        render json: { error: "unknown_task_definition" }, status: :unprocessable_entity
      end

      def show
        render json: job_json(hub_application.jobs.find_by!(public_id: params[:id]))
      end

      private

      def find_definition
        key, version = params.require(:task).to_s.split("@", 2)
        hub_application.task_definitions.find_by!(key:, version:, active: true)
      end

      def json_object(key)
        value = params.require(key)
        raise ActionController::ParameterMissing, key unless value.is_a?(ActionController::Parameters)

        value.to_unsafe_h
      end

      def job_json(job)
        diagnosis = RoutingDiagnosis.new(job).call
        usage = UsageSummary.new(job.job_executions.finalized).call
        { id: job.public_id, status: job.status, task: job.task_definition.reference,
          attempts: job.attempts, output: job.output, error: job.error,
          routing: { pool: job.routing_pool_name, code: diagnosis.code, summary: diagnosis.summary },
          usage: { attempts: usage.fetch(:attempts), reported_attempts: usage.fetch(:reported_attempts),
                   input_tokens: usage.fetch(:input_tokens), output_tokens: usage.fetch(:output_tokens),
                   total_tokens: usage.fetch(:tokens), model_duration_ms: usage.fetch(:model_duration_ms) },
          created_at: job.created_at&.iso8601, completed_at: job.completed_at&.iso8601 }
      end
    end
  end
end

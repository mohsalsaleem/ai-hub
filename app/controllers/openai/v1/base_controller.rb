module Openai
  module V1
    class BaseController < ActionController::API
      IdempotencyConflict = Class.new(StandardError)
      MAX_PAYLOAD_BYTES = 256.kilobytes
      TERMINAL_STATUSES = %w[completed failed dead].freeze

      before_action :authenticate_application!

      rescue_from ActionController::ParameterMissing do |error|
        render_openai_error("Missing required parameter: #{error.param}", code: "invalid_request_error")
      end
      rescue_from ActiveRecord::RecordInvalid do |error|
        render_openai_error(error.record.errors.full_messages.to_sentence, code: "invalid_request_error")
      end
      rescue_from ActiveRecord::RecordNotFound do
        render_openai_error("The requested resource was not found", code: "not_found", status: :not_found)
      end
      rescue_from IdempotencyConflict do
        render_openai_error("The Idempotency-Key was already used with different parameters",
          code: "idempotency_conflict", status: :conflict)
      end

      private

      attr_reader :hub_application

      def authenticate_application!
        @hub_application = HubApplication.authenticate(bearer_token)
        render_openai_error("Invalid application token", code: "invalid_api_key", status: :unauthorized) unless @hub_application
      end

      def bearer_token = request.headers["Authorization"].to_s[/\ABearer (.+)\z/, 1]

      def find_model
        requested = params.require(:model).to_s
        key, version = requested.split("@", 2)
        scope = hub_application.task_definitions.where(key:, executor: "chat_completion", active: true)
        definition = version.present? ? scope.find_by(version:) : scope.order(version: :desc).first
        definition || raise(ActiveRecord::RecordNotFound)
      end

      def create_job(definition, input)
        idempotency_key = request.headers["Idempotency-Key"].presence || "openai-#{SecureRandom.uuid}"
        job = hub_application.jobs.find_or_initialize_by(idempotency_key: idempotency_key.first(200))
        if job.persisted?
          raise IdempotencyConflict unless job.task_definition == definition && job.input == input.deep_stringify_keys
          return job
        end

        job.update!(task_definition: definition, input:)
        job
      end

      def wait_for(job)
        timeout = ENV.fetch("AI_HUB_OPENAI_SYNC_TIMEOUT", "60").to_f.clamp(1, 300)
        deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout
        until job.status.in?(TERMINAL_STATUSES) || Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
          sleep 0.1
          job.reload
        end
        job
      end

      def normalized_messages(value)
        messages = value.is_a?(String) ? [ { "role" => "user", "content" => value } ] : Array(value)
        messages.map do |message|
          message = message.to_unsafe_h if message.respond_to?(:to_unsafe_h)
          role = message.fetch("role", "user").to_s
          content = normalize_content(message["content"])
          { "role" => role, "content" => content }
        end
      rescue KeyError, NoMethodError
        raise ActionController::ParameterMissing, :input
      end

      def normalize_content(content)
        return content if content.is_a?(String)

        Array(content).filter_map do |part|
          part = part.to_unsafe_h if part.respond_to?(:to_unsafe_h)
          part["text"] if part.is_a?(Hash) && %w[input_text output_text text].include?(part["type"].to_s)
        end.join("\n")
      end

      def inference_options
        {}.tap do |options|
          %i[temperature top_p max_tokens stop].each { |key| options[key] = params[key] if params.key?(key) }
          options[:max_tokens] ||= params[:max_completion_tokens] if params.key?(:max_completion_tokens)
          options[:max_tokens] ||= params[:max_output_tokens] if params.key?(:max_output_tokens)
        end
      end

      def canonical_response_usage(job)
        execution = job.job_executions.finalized.where(outcome: "completed", usage_reported: true)
          .order(attempt_number: :desc).first
        return normalize_response_usage(job.output["usage"] || {}) unless execution

        { input_tokens: execution.input_tokens.to_i, input_tokens_details: {},
          output_tokens: execution.output_tokens.to_i, output_tokens_details: {},
          total_tokens: execution.total_tokens.to_i }
      end

      def normalize_response_usage(usage)
        input = usage["input_tokens"] || usage["prompt_tokens"] || 0
        output = usage["output_tokens"] || usage["completion_tokens"] || 0
        { input_tokens: input, input_tokens_details: {}, output_tokens: output,
          output_tokens_details: {}, total_tokens: usage["total_tokens"] || input + output }
      end

      def render_job_error(job)
        message = job.error.is_a?(Hash) ? job.error["message"] : nil
        render_openai_error(message.presence || "Model execution failed", code: "model_error", status: :bad_gateway)
      end

      def render_openai_error(message, code:, status: :unprocessable_entity)
        render json: { error: { message:, type: code, code: } }, status:
      end
    end
  end
end

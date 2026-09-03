module Openai
  module V1
    class ResponsesController < BaseController
      def create
        return render_openai_error("Streaming is not supported yet", code: "unsupported_parameter") if ActiveModel::Type::Boolean.new.cast(params[:stream])
        return render_openai_error("Request is too large", code: "request_too_large", status: :content_too_large) if request.content_length.to_i > MAX_PAYLOAD_BYTES

        definition = find_model
        messages = normalized_messages(params.require(:input))
        messages.unshift({ "role" => "developer", "content" => params[:instructions].to_s }) if params[:instructions].present?
        input = { messages: }.merge(inference_options)
        job = create_job(definition, input)
        job = wait_for(job) unless ActiveModel::Type::Boolean.new.cast(params[:background])
        render_response(job, definition)
      end

      def show
        job = hub_application.jobs.includes(:task_definition).find_by!(public_id: params[:id])
        raise ActiveRecord::RecordNotFound unless job.task_definition.executor == "chat_completion"

        render_response(job, job.task_definition)
      end

      private

      def render_response(job, definition)
        return render_job_error(job) if job.status.in?(%w[failed dead])

        render json: response_json(job, definition)
      end

      def response_json(job, definition)
        completed = job.status == "completed"
        content = completed ? job.output.fetch("content") : nil
        { id: job.public_id, object: "response", created_at: job.created_at.to_i,
          completed_at: job.completed_at&.to_i,
          status: completed ? "completed" : "in_progress", model: definition.reference,
          output: completed ? [ { type: "message", id: "msg_#{job.public_id.delete_prefix('job_')}",
            status: "completed", role: "assistant", content: [ { type: "output_text", text: content, annotations: [] } ] } ] : [],
          output_text: content, usage: completed ? response_usage(job.output["usage"] || {}) : nil, error: nil }
      end

      def response_usage(usage)
        input = usage["input_tokens"] || usage["prompt_tokens"] || 0
        output = usage["output_tokens"] || usage["completion_tokens"] || 0
        { input_tokens: input, input_tokens_details: {}, output_tokens: output,
          output_tokens_details: {}, total_tokens: usage["total_tokens"] || input + output }
      end
    end
  end
end

module Openai
  module V1
    class ChatCompletionsController < BaseController
      def create
        return render_openai_error("Streaming is not supported yet", code: "unsupported_parameter") if ActiveModel::Type::Boolean.new.cast(params[:stream])
        return render_openai_error("Request is too large", code: "request_too_large", status: :content_too_large) if request.content_length.to_i > MAX_PAYLOAD_BYTES

        definition = find_model
        input = { messages: normalized_messages(params.require(:messages)) }.merge(inference_options)
        job = wait_for(create_job(definition, input))
        return render_job_error(job) if job.status.in?(%w[failed dead])
        return render_openai_error("Timed out waiting for the worker; job #{job.public_id} is still running",
          code: "request_timeout", status: :gateway_timeout) unless job.status == "completed"

        render json: completion_json(job, definition)
      end

      private

      def completion_json(job, definition)
        output = job.output
        { id: "chatcmpl_#{job.public_id.delete_prefix('job_')}", object: "chat.completion",
          created: job.created_at.to_i, model: definition.reference,
          choices: [ { index: 0, message: { role: "assistant", content: output.fetch("content") },
                       finish_reason: output["finish_reason"] || "stop" } ], usage: output["usage"] || {} }
      end
    end
  end
end

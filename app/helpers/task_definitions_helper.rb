module TaskDefinitionsHelper
  def executor_label(executor)
    executor.to_s == "chat_completion" ? "Chat completion" : "Structured generation"
  end

  def executor_description(executor)
    if executor.to_s == "chat_completion"
      "OpenAI-compatible requests with prompts and response validation owned by your application."
    else
      "Schema-validated, durable jobs with instructions and contracts owned by AI Hub."
    end
  end

  def executor_endpoint(executor)
    executor.to_s == "chat_completion" ? "/v1/responses or /v1/chat/completions" : "/api/v1/jobs"
  end
end

class UsageSummary
  def initialize(executions)
    @executions = executions
  end

  def call
    if @executions.respond_to?(:where)
      { attempts: @executions.count,
        reported_attempts: @executions.where(usage_reported: true).count,
        completed: @executions.where(outcome: "completed").count,
        input_tokens: @executions.sum(:input_tokens),
        output_tokens: @executions.sum(:output_tokens),
        tokens: @executions.sum(:total_tokens),
        model_duration_ms: @executions.sum(:model_duration_ms) }
    else
      { attempts: @executions.size,
        reported_attempts: @executions.count(&:usage_reported?),
        completed: @executions.count { |execution| execution.outcome == "completed" },
        input_tokens: @executions.sum { |execution| execution.input_tokens.to_i },
        output_tokens: @executions.sum { |execution| execution.output_tokens.to_i },
        tokens: @executions.sum { |execution| execution.total_tokens.to_i },
        model_duration_ms: @executions.sum { |execution| execution.model_duration_ms.to_i } }
    end
  end
end

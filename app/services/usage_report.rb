class UsageReport
  Invalid = Class.new(StandardError)
  SCHEMA_VERSION = 1
  MAX_TOKEN_COUNT = 1_000_000_000
  MAX_DURATION_MS = 86_400_000

  def self.normalize(value)
    return unavailable unless value.present?

    raw = value.respond_to?(:to_unsafe_h) ? value.to_unsafe_h : value.to_h
    raw = raw.stringify_keys
    version = integer(raw.fetch("schema_version", SCHEMA_VERSION), "schema_version", maximum: SCHEMA_VERSION)
    raise Invalid, "Unsupported usage schema version" unless version == SCHEMA_VERSION

    input = token(raw, "input_tokens", "prompt_tokens")
    output = token(raw, "output_tokens", "completion_tokens")
    reported_total = token(raw, "total_tokens")
    total = if input && output
      integer(input + output, "total_tokens", maximum: MAX_TOKEN_COUNT)
    else
      reported_total
    end
    duration = integer(raw["duration_ms"], "duration_ms", maximum: MAX_DURATION_MS, optional: true)
    llm_model = (raw["llm_model"] || raw["model"]).to_s
      .encode("UTF-8", invalid: :replace, undef: :replace).byteslice(0, 120).to_s.scrub.presence

    { usage_reported: true, usage_schema_version: version, llm_model:,
      input_tokens: input, output_tokens: output, total_tokens: total, model_duration_ms: duration }
  rescue NoMethodError, TypeError
    raise Invalid, "Usage must be an object"
  end

  def self.unavailable
    { usage_reported: false, usage_schema_version: nil, llm_model: nil,
      input_tokens: nil, output_tokens: nil, total_tokens: nil, model_duration_ms: nil }
  end

  def self.token(raw, *keys)
    value = keys.filter_map { |key| raw[key] }.first
    integer(value, keys.first, maximum: MAX_TOKEN_COUNT, optional: true)
  end

  def self.integer(value, label, maximum:, optional: false)
    return if optional && value.nil?

    string = value.to_s
    parsed = Integer(string, exception: false) if /\A\d+\z/.match?(string)
    raise Invalid, "#{label} must be an integer between 0 and #{maximum}" unless parsed&.between?(0, maximum)

    parsed
  end

  private_class_method :token, :integer
end

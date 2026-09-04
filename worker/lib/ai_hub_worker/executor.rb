module AiHubWorker
  class Executor
    class Error < StandardError
      attr_reader :usage

      def initialize(message, usage: nil)
        @usage = usage
        super(message)
      end
    end
    Result = Data.define(:output, :usage)

    attr_reader :model_name

    def initialize(config, transport: nil)
      @base = URI(config.model_url.sub(%r{/+\z}, ""))
      @model = config.model
      @api_key = config.model_api_key
      @transport = transport || method(:http_call)
      @model_name = config.model
    end

    def execute(definition, input)
      raise Error, "Input schema mismatch" unless JSONSchemer.schema(definition.fetch("input_schema")).valid?(input)

      started_at = monotonic
      output, raw_usage = case definition.fetch("executor")
      when "structured_generation" then structured_call(definition, input)
      when "chat_completion" then chat_call(definition, input)
      else raise Error, "Unsupported executor"
      end
      raise Error, "Output schema mismatch" unless JSONSchemer.schema(definition.fetch("output_schema")).valid?(output)

      Result.new(output:, usage: usage_payload(raw_usage, duration_ms_since(started_at)))
    rescue Error => e
      raise if e.usage || started_at.nil?

      raise Error.new(e.message, usage: usage_payload({}, duration_ms_since(started_at)))
    end

    private

    def structured_call(definition, input)
      uri = @base.dup
      uri.path = "#{uri.path.sub(%r{/+\z}, "")}/chat/completions"
      request = Net::HTTP::Post.new(uri)
      request["Authorization"] = "Bearer #{@api_key}"
      request["Content-Type"] = "application/json"
      request.body = JSON.generate(
        model: @model,
        messages: [
          { role: "system", content: definition.fetch("instructions") },
          { role: "user", content: JSON.generate(input) }
        ],
        response_format: { type: "json_schema", json_schema: {
          name: definition.fetch("key").tr(".-", "_"), strict: true,
          schema: definition.fetch("output_schema")
        } }
      )
      response = @transport.call(request, uri)
      raise Error, "Model returned HTTP #{response.code}" unless response.code.to_i.between?(200, 299)

      body = JSON.parse(response.body)
      content = body.dig("choices", 0, "message", "content").to_s
      [ JSON.parse(content.sub(/\A```(?:json)?\s*/i, "").sub(/\s*```\z/, "")), body["usage"] || {} ]
    rescue JSON::ParserError => e
      raise Error, "Model returned invalid JSON: #{e.message}"
    rescue Net::OpenTimeout, Net::ReadTimeout, SocketError, SystemCallError => e
      raise Error, "Model unavailable: #{e.class}"
    end

    def chat_call(definition, input)
      uri = completion_uri
      request = Net::HTTP::Post.new(uri)
      request["Authorization"] = "Bearer #{@api_key}"
      request["Content-Type"] = "application/json"
      messages = input.fetch("messages").dup
      instructions = definition.fetch("instructions").to_s
      messages.unshift({ "role" => "system", "content" => instructions }) if instructions.length.positive?
      request.body = JSON.generate({ model: @model, messages: }.merge(input.slice("temperature", "top_p", "max_tokens", "stop")))
      response = @transport.call(request, uri)
      raise Error, "Model returned HTTP #{response.code}" unless response.code.to_i.between?(200, 299)

      body = JSON.parse(response.body)
      choice = body.fetch("choices").first || {}
      usage = body["usage"] || {}
      [ { "content" => choice.dig("message", "content").to_s,
          "finish_reason" => choice["finish_reason"], "usage" => usage }, usage ]
    rescue JSON::ParserError, KeyError => e
      raise Error, "Model returned invalid response: #{e.message}"
    rescue Net::OpenTimeout, Net::ReadTimeout, SocketError, SystemCallError => e
      raise Error, "Model unavailable: #{e.class}"
    end

    def completion_uri
      uri = @base.dup
      uri.path = "#{uri.path.sub(%r{/+\z}, "")}/chat/completions"
      uri
    end

    def usage_payload(raw, duration_ms)
      raw = raw.to_h
      input = raw["input_tokens"] || raw["prompt_tokens"]
      output = raw["output_tokens"] || raw["completion_tokens"]
      total = input && output ? input.to_i + output.to_i : raw["total_tokens"]
      { schema_version: 1, llm_model: model_name, duration_ms:,
        input_tokens: input, output_tokens: output, total_tokens: total }.compact
    end

    def duration_ms_since(started_at)
      [ ((monotonic - started_at) * 1000).round, 0 ].max
    end

    def monotonic
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end

    def http_call(request, uri)
      Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https",
        open_timeout: 10, read_timeout: 300) { |http| http.request(request) }
    end
  end
end

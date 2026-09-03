module AiHubWorker
  class Executor
    Error = Class.new(StandardError)

    def initialize(config, transport: nil)
      @base = URI(config.model_url.sub(%r{/+\z}, ""))
      @model = config.model
      @api_key = config.model_api_key
      @transport = transport || method(:http_call)
    end

    def execute(definition, input)
      raise Error, "Unsupported executor" unless definition.fetch("executor") == "structured_generation"
      raise Error, "Input schema mismatch" unless JSONSchemer.schema(definition.fetch("input_schema")).valid?(input)

      output = model_call(definition, input)
      raise Error, "Output schema mismatch" unless JSONSchemer.schema(definition.fetch("output_schema")).valid?(output)

      output
    end

    private

    def model_call(definition, input)
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

      content = JSON.parse(response.body).dig("choices", 0, "message", "content").to_s
      JSON.parse(content.sub(/\A```(?:json)?\s*/i, "").sub(/\s*```\z/, ""))
    rescue JSON::ParserError => e
      raise Error, "Model returned invalid JSON: #{e.message}"
    rescue Net::OpenTimeout, Net::ReadTimeout, SocketError, SystemCallError => e
      raise Error, "Model unavailable: #{e.class}"
    end

    def http_call(request, uri)
      Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https",
        open_timeout: 10, read_timeout: 300) { |http| http.request(request) }
    end
  end
end

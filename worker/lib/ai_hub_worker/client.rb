module AiHubWorker
  class Client
    class Error < StandardError
      attr_reader :status, :code

      def initialize(message, status: nil, code: nil)
        @status = status
        @code = code
        super(message)
      end
    end
    RetryableError = Class.new(Error)

    def initialize(config, http_start: Net::HTTP.method(:start))
      @base = URI(config.hub_url.sub(%r{/+\z}, ""))
      @token = config.worker_token
      @worker_id = config.worker_id
      @identity = Identity.new(config.state_path)
      @enrolled = false
      @http_start = http_start
    end

    def enroll
      return if @enrolled

      post("/api/v1/worker/enroll", { public_key: @identity.public_key_pem,
        proof: Base64.strict_encode64(@identity.enrollment_proof) }, signed: false)
      @enrolled = true
    end

    def claim(wait_seconds:)
      post("/api/v1/worker/claims", { wait_seconds: })
    end

    def definition(digest)
      request(:get, "/api/v1/worker/task_definitions/#{digest}")
    end

    def renew(job_id, lease_token)
      post("/api/v1/worker/jobs/#{job_id}/renew", { lease_token: })
    end

    def deliver(path, payload)
      post(path, payload)
    end

    private

    def post(path, payload, signed: true) = request(:post, path, payload, signed:)

    def request(method, path, payload = nil, signed: true)
      uri = @base.dup
      uri.path = path
      request = method == :get ? Net::HTTP::Get.new(uri) : Net::HTTP::Post.new(uri)
      request["Content-Type"] = "application/json"
      request["X-Worker-Id"] = @worker_id
      request["X-Worker-Version"] = AiHubWorker::VERSION
      request["X-Worker-Capabilities"] = "structured_generation,chat_completion"
      body = payload ? JSON.generate(payload) : ""
      request.body = body if payload
      signed ? sign!(request, method, uri.request_uri, body) : request["Authorization"] = "Bearer #{@token}"
      response = @http_start.call(uri.host, uri.port, use_ssl: uri.scheme == "https",
        open_timeout: 10, read_timeout: 35) { |http| http.request(request) }
      body = response.body.to_s.empty? ? {} : JSON.parse(response.body)
      return body if response.code.to_i.between?(200, 299)

      error = "Hub returned HTTP #{response.code}: #{body["error"] || "unknown_error"}"
      error_class = response.code.to_i >= 500 ? RetryableError : Error
      raise error_class.new(error, status: response.code.to_i, code: body["error"])
    rescue Net::OpenTimeout, Net::ReadTimeout, SocketError, SystemCallError => e
      raise RetryableError, "Hub unavailable: #{e.class}"
    end

    def sign!(request, method, path, body)
      timestamp = Time.now.to_i.to_s
      nonce = SecureRandom.hex(24)
      message = [ method.to_s.upcase, path, timestamp, nonce,
        OpenSSL::Digest::SHA256.hexdigest(body) ].join("\n")
      request["X-Worker-Key-Id"] = @identity.fingerprint
      request["X-Worker-Timestamp"] = timestamp
      request["X-Worker-Nonce"] = nonce
      request["X-Worker-Signature"] = Base64.strict_encode64(@identity.sign(message))
    end
  end
end

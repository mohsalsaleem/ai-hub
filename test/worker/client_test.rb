require "test_helper"
require "tmpdir"
require_relative "../../worker/lib/ai_hub_worker"

class WorkerClientTest < ActiveSupport::TestCase
  test "enrolls with bearer token then signs runtime requests" do
    Dir.mktmpdir do |directory|
      config = AiHubWorker::Config.new(hub_url: "https://hub.example", worker_token: "secret",
        worker_id: "worker-one", model_url: "http://model.test", model: "model",
        model_api_key: "local", state_path: directory, poll_wait_seconds: 0)
      requests = []
      response = Struct.new(:code, :body).new("200", "{}")
      transport = lambda do |*args, **options, &block|
        http = Object.new
        http.define_singleton_method(:request) do |request|
          requests << request
          response
        end
        block.call(http)
      end

      client = AiHubWorker::Client.new(config, http_start: transport)
      client.enroll
      client.claim(wait_seconds: 0)

      enrollment, claim = requests
      enrollment_payload = JSON.parse(enrollment.body)
      public_key = OpenSSL::PKey.read(enrollment_payload.fetch("public_key"))
      fingerprint = OpenSSL::Digest::SHA256.hexdigest(public_key.public_to_der)

      assert_equal "Bearer secret", enrollment["Authorization"]
      assert public_key.verify(nil, Base64.strict_decode64(enrollment_payload.fetch("proof")),
        "aihub-worker-enrollment/v1\n#{fingerprint}")
      assert_nil claim["Authorization"]
      assert_equal fingerprint, claim["X-Worker-Key-Id"]

      canonical = WorkerRequestSignature.canonical(method: "POST", path: "/api/v1/worker/claims",
        timestamp: claim["X-Worker-Timestamp"], nonce: claim["X-Worker-Nonce"], body: claim.body)
      assert public_key.verify(nil, Base64.strict_decode64(claim["X-Worker-Signature"]), canonical)
    end
  end
end

require "test_helper"
require "tmpdir"
require_relative "../../worker/lib/ai_hub_worker"

class WorkerIdentityTest < ActiveSupport::TestCase
  test "identity is stable on disk and private key file is owner-only" do
    Dir.mktmpdir do |directory|
      first = AiHubWorker::Identity.new(directory)
      second = AiHubWorker::Identity.new(directory)

      assert_equal first.fingerprint, second.fingerprint
      assert_equal 0o600, File.stat(File.join(directory, "identity.pem")).mode & 0o777
      public_key = OpenSSL::PKey.read(first.public_key_pem)
      assert public_key.verify(nil, first.enrollment_proof,
        "aihub-worker-enrollment/v1\n#{first.fingerprint}")
    end
  end
end

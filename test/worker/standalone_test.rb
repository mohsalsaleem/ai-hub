require "test_helper"
require "open3"
require "rbconfig"

class StandaloneWorkerTest < ActiveSupport::TestCase
  test "cached Unicode definitions survive an ASCII process locale" do
    script = <<~'RUBY'
      require "json"
      require "tmpdir"
      require_relative "worker/lib/ai_hub_worker/definition_cache"
      abort "wrong test encoding" unless Encoding.default_external == Encoding::US_ASCII
      Dir.mktmpdir do |directory|
        cache = AiHubWorker::DefinitionCache.new(directory)
        digest = "a" * 64
        definition = { "digest" => digest, "instructions" => "Return \u2014 r\u00e9sum\u00e9 \u4e2d\u6587" }
        cache.fetch(digest) { definition }
        restored = cache.fetch(digest) { abort "unexpected cache miss" }
        abort "Unicode changed" unless restored == definition
      end
    RUBY
    assert_standalone_success(script, "-EUS-ASCII:US-ASCII")
  end

  test "standalone runner reports a bounded failure without Active Support" do
    script = <<~'RUBY'
      require_relative "worker/lib/ai_hub_worker/runner"
      abort "Active Support loaded" if "".respond_to?(:first)
      rows = []
      outbox = Object.new
      outbox.define_singleton_method(:enqueue) { |**row| rows << row }
      cache = Object.new
      cache.define_singleton_method(:fetch) { |*| raise "x" * 700 }
      runner = AiHubWorker::Runner.new(client: Object.new, executor: Object.new,
        cache: cache, outbox: outbox, poll_wait_seconds: 0)
      runner.define_singleton_method(:start_lease_renewer) { |*| nil }
      runner.send(:process, { "id" => "job_test", "task_digest" => "digest" }, "lease")
      abort "missing failure" unless rows.length == 1
      row = rows.fetch(0)
      abort "wrong endpoint" unless row[:path] == "/api/v1/worker/jobs/job_test/fail"
      abort "wrong error" unless row.dig(:payload, :error, :code) == "execution_failed"
      abort "unbounded message" unless row.dig(:payload, :error, :message) == "x" * 500
    RUBY
    assert_standalone_success(script)
  end

  private

  def assert_standalone_success(script, *options)
    stdout, stderr, status = Open3.capture3(RbConfig.ruby, *options, "-e", script, chdir: Rails.root.to_s)
    assert status.success?, "Standalone worker failed:\n#{stdout}\n#{stderr}"
  end
end

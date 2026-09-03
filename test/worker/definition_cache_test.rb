require "test_helper"
require_relative "../../worker/lib/ai_hub_worker"

class DefinitionCacheTest < ActiveSupport::TestCase
  test "downloads an immutable definition once" do
    Dir.mktmpdir do |directory|
      cache = AiHubWorker::DefinitionCache.new(directory)
      calls = 0
      digest = "a" * 64
      twice = 2.times.map { cache.fetch(digest) { calls += 1; { "digest" => digest, "instructions" => "Do it" } } }
      assert_equal 1, calls
      assert_equal twice.first, twice.last
    end
  end
end

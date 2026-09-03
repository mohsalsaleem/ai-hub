require "test_helper"
require_relative "../../worker/lib/ai_hub_worker"

class ResultOutboxTest < ActiveSupport::TestCase
  test "persists results until explicitly acknowledged" do
    Dir.mktmpdir do |directory|
      path = File.join(directory, "outbox.sqlite3")
      outbox = AiHubWorker::ResultOutbox.new(path)
      outbox.enqueue(job_id: "job_1", path: "/complete", payload: { output: { ok: true } })

      reloaded = AiHubWorker::ResultOutbox.new(path)
      rows = []
      reloaded.each { |*row| rows << row }
      assert_equal "job_1", rows.first[0]
      assert_equal({ "output" => { "ok" => true } }, rows.first[2])

      reloaded.delete("job_1")
      assert reloaded.empty?
    end
  end
end

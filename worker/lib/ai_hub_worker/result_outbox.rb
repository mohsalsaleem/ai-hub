require "fileutils"

module AiHubWorker
  class ResultOutbox
    MAX_ROWS = 1_000
    MAX_BYTES = 256 * 1024 * 1024
    MAX_RESULT_BYTES = 256 * 1024

    def initialize(path)
      FileUtils.mkdir_p(File.dirname(path), mode: 0o700)
      @path = path
      @database = SQLite3::Database.new(path)
      @database.execute("PRAGMA journal_mode=WAL")
      @database.execute("PRAGMA busy_timeout=5000")
      @database.execute <<~SQL
        CREATE TABLE IF NOT EXISTS results (
          job_id TEXT PRIMARY KEY, path TEXT NOT NULL, payload TEXT NOT NULL,
          created_at TEXT NOT NULL
        )
      SQL
    end

    def enqueue(job_id:, path:, payload:)
      raise "Result outbox is full" if full?
      encoded = JSON.generate(payload)
      raise "Result exceeds outbox item limit" if encoded.bytesize > MAX_RESULT_BYTES

      @database.execute("INSERT OR REPLACE INTO results(job_id, path, payload, created_at) VALUES (?, ?, ?, ?)",
        [ job_id, path, encoded, Time.now.utc.iso8601 ])
    end

    def each
      @database.execute("SELECT job_id, path, payload FROM results ORDER BY created_at") do |job_id, path, payload|
        yield job_id, path, JSON.parse(payload)
      end
    end

    def delete(job_id) = @database.execute("DELETE FROM results WHERE job_id = ?", [ job_id ])
    def empty? = @database.get_first_value("SELECT COUNT(*) FROM results").zero?

    def full?
      @database.get_first_value("SELECT COUNT(*) FROM results") >= MAX_ROWS ||
        (File.exist?(@path) && File.size(@path) >= MAX_BYTES)
    end
  end
end

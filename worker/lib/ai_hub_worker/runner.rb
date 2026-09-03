module AiHubWorker
  class Runner
    def initialize(client:, executor:, cache:, outbox:, poll_wait_seconds:, logger: nil, sleeper: nil)
      @client = client
      @executor = executor
      @cache = cache
      @outbox = outbox
      @poll_wait_seconds = poll_wait_seconds
      @logger = logger || ->(message) { puts("[#{Time.now.utc.iso8601}] #{message}") }
      @sleeper = sleeper || ->(seconds) { sleep(seconds) }
      @stopping = false
    end

    def stop = @stopping = true

    def run
      @logger.call("AI Hub worker #{AiHubWorker::VERSION} started")
      until @stopping
        begin
          @client.enroll
          unless drain_outbox
            @sleeper.call(5)
            next
          end
          claim = @client.claim(wait_seconds: @poll_wait_seconds)
          process(claim.fetch("job"), claim["lease_token"]) if claim["job"]
        rescue Client::RetryableError => e
          @logger.call(e.message)
          @sleeper.call(5)
        end
      end
    end

    private

    def drain_outbox
      current_job_id = nil
      @outbox.each do |job_id, path, payload|
        current_job_id = job_id
        @client.deliver(path, payload)
        @outbox.delete(job_id)
      end
      true
    rescue Client::Error => e
      if e.status == 409 && e.code == "stale_lease"
        @logger.call("Discarding superseded result")
        @outbox.delete(current_job_id)
        retry
      end
      @logger.call("Result delivery deferred: #{e.message}")
      false
    end

    def process(job, lease_token)
      renewer = start_lease_renewer(job.fetch("id"), lease_token)
      definition = @cache.fetch(job.fetch("task_digest")) { @client.definition(job.fetch("task_digest")) }
      output = @executor.execute(definition, job.fetch("input"))
      enqueue(job.fetch("id"), "complete", lease_token:, output:)
    rescue StandardError => e
      enqueue(job.fetch("id"), "fail", lease_token:,
        error: { code: "execution_failed", message: e.message.to_s.first(500), retryable: true })
    ensure
      renewer&.kill
      renewer&.join
    end

    def enqueue(job_id, action, payload)
      @outbox.enqueue(job_id:, path: "/api/v1/worker/jobs/#{job_id}/#{action}", payload:)
    end

    def start_lease_renewer(job_id, lease_token)
      Thread.new do
        loop do
          @sleeper.call(60)
          @client.renew(job_id, lease_token)
        end
      rescue StandardError => e
        @logger.call("Lease renewal stopped: #{e.class}")
      end
    end
  end
end

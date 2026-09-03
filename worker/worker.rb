#!/usr/bin/env ruby
$stdout.sync = true

require_relative "lib/ai_hub_worker"

config = AiHubWorker::Config.from_env
runner = AiHubWorker::Runner.new(
  client: AiHubWorker::Client.new(config),
  executor: AiHubWorker::Executor.new(config),
  cache: AiHubWorker::DefinitionCache.new(File.join(config.state_path, "definitions")),
  outbox: AiHubWorker::ResultOutbox.new(File.join(config.state_path, "outbox.sqlite3")),
  poll_wait_seconds: config.poll_wait_seconds
)
%w[INT TERM].each { |signal| trap(signal) { runner.stop } }
runner.run

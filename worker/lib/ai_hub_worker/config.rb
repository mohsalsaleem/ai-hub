module AiHubWorker
  Config = Data.define(:hub_url, :worker_token, :worker_id, :model_url, :model, :model_api_key,
    :state_path, :poll_wait_seconds) do
    def self.from_env(env = ENV)
      new(
        hub_url: env.fetch("AI_HUB_URL"), worker_token: env.fetch("AI_HUB_WORKER_TOKEN"),
        worker_id: env.fetch("AI_HUB_WORKER_ID", Socket.gethostname),
        model_url: env.fetch("AI_MODEL_URL", "http://127.0.0.1:8080/v1"),
        model: env.fetch("AI_MODEL", "local-model"), model_api_key: env.fetch("AI_MODEL_API_KEY", "local"),
        state_path: File.expand_path(env.fetch("AI_HUB_STATE_PATH", "~/.ai-hub")),
        poll_wait_seconds: env.fetch("AI_HUB_POLL_WAIT", "20").to_i.clamp(0, 20)
      )
    end
  end
end

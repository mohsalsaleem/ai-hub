# AI Hub

AI Hub is a self-hosted, outbound-only job bridge between applications and
private local language models. Applications submit durable structured jobs to
the Hub; a worker beside the model claims them over HTTPS and returns
schema-validated results. The model machine never accepts an inbound internet
connection.

This repository is an early `0.1.0-dev` implementation. It deliberately has no
message broker, arbitrary code execution, tool calling, or hosted dependency.

## Architecture

```text
Applications -> Rails Hub + SQLite <- long polling -> local worker -> model
```

- Rails owns authentication, immutable task definitions, idempotent jobs,
  leases, retries, results, metrics, and the operations UI.
- SQLite runs in WAL mode. The initial deployment must use one Hub instance
  and keep `storage/` on durable disk.
- The Ruby worker caches definitions and stores completed results in a bounded
  local SQLite outbox until the Hub acknowledges them.
- Applications own deterministic validation and business persistence.

## Local setup

Requirements: Ruby 3.3, SQLite, and an OpenAI-compatible model endpoint.

```bash
bin/setup
bin/rails db:migrate
APP_NAME=Sums APP_SLUG=sums WORKER_NAME=Home bin/rails hub:bootstrap
AI_HUB_ADMIN_PASSWORD=local bin/rails server
```

Save the two tokens printed by `hub:bootstrap`; plaintext tokens are shown
once. Start the worker in another terminal:

```bash
AI_HUB_URL=http://127.0.0.1:3000 \
AI_HUB_WORKER_TOKEN=aih_... \
AI_MODEL_URL=http://127.0.0.1:8080/v1 \
AI_MODEL=local-model \
bundle exec ruby worker/worker.rb
```

Open `http://127.0.0.1:3000` for job, worker, and task health.

## First job

Register an immutable structured task using the application token:

```bash
curl -X POST http://127.0.0.1:3000/api/v1/task_definitions \
  -H 'Authorization: Bearer aih_...' -H 'Content-Type: application/json' \
  -d '{"task_definition":{"key":"example.summarize","version":1,
    "instructions":"Summarize the supplied text without inventing facts.",
    "input_schema":{"type":"object","required":["text"],"properties":{"text":{"type":"string"}}},
    "output_schema":{"type":"object","required":["summary"],"properties":{"summary":{"type":"string"}}}}}'
```

Submit a job:

```bash
curl -X POST http://127.0.0.1:3000/api/v1/jobs \
  -H 'Authorization: Bearer aih_...' -H 'Content-Type: application/json' \
  -d '{"task":"example.summarize@1","idempotency_key":"demo-1",
    "input":{"text":"AI Hub connects applications to a private model."}}'
```

The create response includes the job ID and current status. Poll
`GET /api/v1/jobs/:id` with the same application token until it reaches a
terminal status:

```bash
curl http://127.0.0.1:3000/api/v1/jobs/JOB_ID \
  -H 'Authorization: Bearer aih_...'
```

`completed` responses include the schema-validated `output`. `failed` and
`dead` responses include `error`. Applications should persist the Hub job ID
and apply a result idempotently because worker execution is at least once.

AI Hub 0.1 does not push callbacks or webhooks. Polling is currently the only
application notification mechanism. Signed, retryable webhooks are planned;
the status endpoint will remain the recovery path after they are introduced.

## Safety and limits

- Task definitions are immutable by application, key, and version.
- Application and worker credentials are separate SHA-256-digested bearer tokens.
- Job input and output requests are capped at 256 KiB.
- Definitions are capped at 96 KiB per API request.
- Leases expire and can be reclaimed after worker failure.
- Retryable failures use bounded exponential backoff and at most ten attempts.
- Worker results are accepted only for the current lease; repeated successful
  completion is acknowledged idempotently.
- The local outbox stops new work instead of silently dropping results.
- Production UI requires `AI_HUB_ADMIN_PASSWORD`.

See [docs/protocol.md](docs/protocol.md) for lifecycle and API semantics.

## Tests

```bash
bin/rails db:test:prepare test
bin/rubocop
bin/brakeman --no-pager
```

## Deployment

Production desired state is recorded in `.coolify/deploy.yaml`. The initial
deployment runs one Rails instance and mounts a named persistent volume at
`/rails/storage`; do not add replicas while SQLite is in use. Container startup
runs `bin/rails db:prepare`, and `/up` is the health check.

Coolify must provide `RAILS_MASTER_KEY` and `AI_HUB_ADMIN_PASSWORD` as secrets.
The SQLite volume is backed up daily with 14-day retention. To restore, stop
the application, restore the complete storage-volume snapshot, then start the
same known-good release and verify `/up` plus an authenticated job read. Record
the restore date in `.coolify/deploy.yaml` before marking `restore_tested` true.

Roll back application code to the previous healthy Coolify deployment. A code
rollback does not roll back SQLite; restore the volume only when data itself is
damaged. PostgreSQL becomes the upgrade path when multiple Hub instances or
sustained concurrent writes are required.

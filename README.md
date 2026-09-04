# AI Hub

AI Hub is an open-source, outbound-only model inference platform connecting
applications to private, shared, and eventually independently operated models.
Applications submit durable structured jobs to the Hub; a worker beside the
model claims them over HTTPS and returns schema-validated results. The model
machine never accepts an inbound internet connection.

This repository is an early `0.2.0-dev` implementation. It deliberately has no
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
- Official workers enroll a local Ed25519 identity and sign every runtime
  request. Existing unenrolled workers retain bearer-token compatibility.
- Applications own deterministic validation and business persistence.
- Organizations are isolated tenants. Cross-organization model work is allowed
  only through an explicit shared-pool consumer grant.
- Applications default to owner-operated workers. Owners can explicitly lower
  the minimum trust level and restrict an application to a named worker pool.

## Local setup

Requirements: Ruby 3.3, SQLite, and an OpenAI-compatible model endpoint.

```bash
bin/setup
bin/rails db:migrate
bin/rails server
```

Open `http://127.0.0.1:3000/registration/new` to create the first organization
owner. The console then lets the owner create applications, publish task
definitions, inspect jobs, and issue worker credentials. Plaintext application
tokens and worker enrollment grants are shown once; AI Hub stores only their
digests.

For scripted bootstrapping instead, run:

```bash
ORG_NAME=SUMS APP_NAME=Sums APP_SLUG=sums WORKER_NAME=Home bin/rails hub:bootstrap
```

Start the worker in another terminal:

```bash
AI_HUB_URL=http://127.0.0.1:3000 \
AI_HUB_WORKER_TOKEN=aih_... \
AI_MODEL_URL=http://127.0.0.1:8080/v1 \
AI_MODEL=local-model \
bundle exec ruby worker/worker.rb
```

Or run the standalone worker container:

```bash
cd worker
cp .env.example .env
# Put the issued worker token in .env, then:
docker compose up -d --build
```

The Compose file can also read `AI_HUB_WORKER_TOKEN` directly from the shell;
an `.env` file is optional.

On first connection, the official worker creates an Ed25519 key in
`AI_HUB_STATE_PATH` and enrolls its public identity using the worker token.
New enrollment grants expire after 24 hours and are consumed by enrollment.
After enrollment, runtime requests are signed and the bearer token is no longer
accepted for that worker. Rotating the token in the console resets the identity
and issues a fresh grant.

On the current macOS model host, `worker/com.mohsal.ai-hub-worker.plist` runs
the worker as a login service. Its wrapper reads the token from macOS Keychain;
the plist and repository contain no credential.

`worker/update-from-main` is safe to run daily from cron. It refuses to update
a non-`main` or dirty checkout, fast-forwards from `origin/main`, installs any
changed bundle dependencies, and restarts the LaunchAgent only after an update.
The current macOS host schedules it at 04:45 using
`worker/com.mohsal.ai-hub-worker-update.plist`.

Open `http://127.0.0.1:3000` for the public product page,
`http://127.0.0.1:3000/docs` for the browsable integration guide, and
`http://127.0.0.1:3000/dashboard` for the authenticated operations console.

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

## OpenAI-compatible API

AI Hub also presents chat task definitions as OpenAI-compatible models. From an
application's console page, choose **Add OpenAI model**, give the profile a key
such as `assistant.general`, and publish its system instructions. The standard
chat input and output schemas are filled in automatically.

Use the application's existing token with an OpenAI client and set its base URL
to the Hub's `/v1` path. Model IDs are immutable task references:

```bash
curl http://127.0.0.1:3000/v1/models \
  -H 'Authorization: Bearer aih_...'

curl -X POST http://127.0.0.1:3000/v1/chat/completions \
  -H 'Authorization: Bearer aih_...' -H 'Content-Type: application/json' \
  -d '{"model":"assistant.general@1","messages":[{"role":"user","content":"Hello"}]}'
```

Chat Completions waits up to `AI_HUB_OPENAI_SYNC_TIMEOUT` seconds (60 by
default) for the existing pull-based worker job. Worker claim requests are
long polls, so an idle connected worker normally receives a new job within
500 ms rather than after the configured long-poll duration.

The Responses API supports both synchronous and durable background requests:

```bash
curl -X POST http://127.0.0.1:3000/v1/responses \
  -H 'Authorization: Bearer aih_...' -H 'Content-Type: application/json' \
  -d '{"model":"assistant.general@1","input":"Explain WAL mode","background":true}'

curl http://127.0.0.1:3000/v1/responses/JOB_ID \
  -H 'Authorization: Bearer aih_...'
```

The initial compatibility layer supports text messages, model listing,
non-streaming Chat Completions, and synchronous/background Responses. Tool
calls, images, audio, embeddings, and SSE streaming are not yet implemented.
See [docs/openai-compatibility.md](docs/openai-compatibility.md) for model setup,
SDK configuration, request semantics, timeouts, and operational guidance.

## Trust-aware routing

Every worker has an owner-assigned trust level: owner operated, organization
managed, verified provider, or external provider. Every application has a
minimum accepted level and may be restricted to one accessible worker pool. A
worker must pass organization or shared-pool access, application trust, pool,
participation, availability, concurrency, and task capability checks before it
can claim a job.

New applications require owner-operated workers by default. Lower-trust and
independently operated workers receive no work until an owner explicitly opts
an application into that trust level. Trust labels are policy assertions made
by the organization owner; cryptographic enrollment proves device-key
possession but does not verify the operator or model.

## Shared pools

The first shared-capacity boundary uses provider-owned pools and explicit
consumer organization grants. A provider creates a shared pool in Hosting,
adds its own workers, marks those workers as shared capacity, and grants access
using the consumer organization's slug. The granted pool then appears in that
consumer's application settings.

Shared pools are not publicly discoverable. Consumers see the pool name and a
general routing explanation, never worker names, machine details, or provider
identity. A consumer must explicitly choose external or verified provider
trust before a cross-organization worker can claim its runs. Revoking a grant
removes the pool from future application routing without broadening queued runs
to automatic routing.

## Safety and limits

- Task definitions are immutable by application, key, and version.
- Browser access uses Rails' built-in password authentication and signed
  database-backed sessions. Registration is intentionally open in this first
  release; email verification and password recovery are not yet enabled.
- Application credentials and initial worker enrollment credentials are
  separate SHA-256-digested bearer tokens.
- Enrolled workers authenticate runtime requests with an Ed25519 signature;
  timestamps and stored nonces prevent altered or replayed requests.
- Worker enrollment grants expire after 24 hours, are accepted once, and are
  revoked when a worker is reset or revoked.
- Enrollment, identity reset, revocation, trust, and pool changes are recorded
  in a per-worker audit trail without storing plaintext credentials.
- Job input and output requests are capped at 256 KiB.
- Definitions are capped at 96 KiB per API request.
- Leases expire and can be reclaimed after worker failure.
- Retryable failures use bounded exponential backoff and at most ten attempts.
- Worker results are accepted only for the current lease; repeated successful
  completion is acknowledged idempotently.
- The local outbox stops new work instead of silently dropping results.
- Organization membership is the authorization boundary for every console read
  and mutation. Cross-organization claims require an explicit shared-pool
  grant, and task definitions are available to a worker only while it holds the
  active run lease.

See [docs/protocol.md](docs/protocol.md) for lifecycle and API semantics.
See [docs/worker-identity.md](docs/worker-identity.md) and
[docs/threat-model.md](docs/threat-model.md) for worker trust boundaries.
See [docs/product-direction.md](docs/product-direction.md) for the product
model, console structure, provider participation, and phased delivery plan.
Delivery status is tracked in
[docs/implementation-progress.md](docs/implementation-progress.md).
The path from private deployments to independently operated workers is in the
[decentralized roadmap](docs/decentralized-roadmap.md).

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

Coolify must provide `RAILS_MASTER_KEY` as a secret. After migrating an existing
single-admin installation, create its first owner without rotating existing API
or worker tokens:

```bash
ORG_SLUG=sums OWNER_EMAIL=owner@example.com OWNER_PASSWORD='change-me' \
  bin/rails hub:create_owner
```

The SQLite volume is backed up daily with 14-day retention. To restore, stop
the application, restore the complete storage-volume snapshot, then start the
same known-good release and verify `/up` plus an authenticated job read. Record
the restore date in `.coolify/deploy.yaml` before marking `restore_tested` true.

Roll back application code to the previous healthy Coolify deployment. A code
rollback does not roll back SQLite; restore the volume only when data itself is
damaged. PostgreSQL becomes the upgrade path when multiple Hub instances or
sustained concurrent writes are required.

# AI Hub protocol 0.2

All API requests use JSON. Application credentials use bearer authentication
and can register task definitions and submit or read only their own jobs.
Workers enroll an Ed25519 device identity, then sign runtime requests.

## Worker identity

New workers begin with an owner-issued bearer token. The official worker creates
an Ed25519 key in its local state directory and calls
`POST /api/v1/worker/enroll`. The private key never leaves the worker host.

After enrollment, bearer authentication is disabled for that worker. Each
runtime request carries the key fingerprint, timestamp, random nonce, and a
signature binding the HTTP method, path, timestamp, nonce, and request body.
The Hub rejects stale timestamps, altered requests, and reused nonces.

Workers that have not enrolled remain compatible with bearer authentication so
existing deployments can upgrade without downtime. Rotating a worker token
clears its enrolled identity and permits a fresh enrollment. See
[worker identity](worker-identity.md) and the [threat model](threat-model.md).

## Trust-aware routing

Workers have one owner-assigned trust tier, ordered from external provider,
verified provider, organization managed, to owner operated. Applications
default to owner operated as their minimum accepted tier. An owner may
explicitly accept a lower tier and may bind an application to one worker pool.

A claim is eligible only when all of these checks pass:

1. The worker and application belong to the same organization.
2. The worker meets the application's minimum trust tier.
3. The worker belongs to the application's selected pool, when one is set.
4. The worker advertises the executor and every required task capability.

Worker trust is administrative policy, not cryptographic attestation. Signed
requests prove possession of an enrolled device key. They do not prove who
operates that device or which model it runs.

## Task definitions

A definition contains an application-scoped `key`, positive integer `version`,
executor, instructions, input/output JSON Schemas, and capability requirements.
It receives a canonical SHA-256 digest and cannot be changed in place. Publish
a new version when instructions or schemas change.

The `structured_generation` executor validates JSON input and output against
the application schemas. The `chat_completion` executor uses the standard chat
schemas supplied by AI Hub and exposes the definition as an OpenAI-compatible
model. Requirements are boolean capability names; a worker receives a job only
when it advertises its executor and every required capability.

## Job lifecycle

```text
queued -> leased -> completed
   ^         |
   |         +-> queued (retryable failure)
   |         +-> failed (permanent failure)
   |         +-> dead (attempt budget exhausted)
   +---------+   (expired lease)
```

Applications submit with an idempotency key unique within that application.
Submitting the same key again returns the original job.

Claims issue a random lease token valid for 180 seconds. A worker renews it
during long inference. Completion and failure require the current lease token;
an old worker cannot overwrite a job after it has been reclaimed.

## Endpoints

Application API:

- `POST /api/v1/task_definitions`
- `GET /api/v1/task_definitions`
- `POST /api/v1/jobs`
- `GET /api/v1/jobs/:id`

OpenAI-compatible application API:

- `GET /v1/models`
- `POST /v1/chat/completions`
- `POST /v1/responses`
- `GET /v1/responses/:id`

Worker API:

- `POST /api/v1/worker/enroll`
- `POST /api/v1/worker/claims`
- `GET /api/v1/worker/task_definitions/:digest`
- `POST /api/v1/worker/jobs/:id/renew`
- `POST /api/v1/worker/jobs/:id/complete`
- `POST /api/v1/worker/jobs/:id/fail`
- `POST /api/v1/worker/metrics`

## Receiving job results

`POST /api/v1/jobs` returns the durable job resource. Applications retain its
`id` and poll `GET /api/v1/jobs/:id` using their application bearer token.
Applications can only read their own jobs.

```json
{
  "id": "01J...",
  "status": "completed",
  "task": "example.summarize@1",
  "attempts": 1,
  "output": { "summary": "..." },
  "error": null,
  "created_at": "2026-09-03T10:00:00Z",
  "completed_at": "2026-09-03T10:00:04Z"
}
```

`queued` and `leased` are non-terminal. `completed`, `failed`, and `dead` are
terminal. `output` is present after successful completion; unsuccessful jobs
use `error`.

Version 0.1 does not deliver webhooks or callbacks. Applications must poll the
status endpoint. A future signed-webhook delivery layer may provide faster
notification, but this endpoint will remain the authoritative fallback.

## Delivery guarantees

The protocol provides at-least-once execution and idempotent job completion.
A worker may repeat model inference when it crashes before persisting its
result. Applications must use the Hub job ID or their idempotency key when
applying completed output to business state.

The local result outbox provides durable delivery after inference. If its
bounded storage is full, the worker stops claiming jobs. Metrics are lossy and
may replace older samples; job results are never intentionally dropped.

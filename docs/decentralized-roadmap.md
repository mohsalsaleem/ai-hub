# Shared model network roadmap

AI Hub begins as a private control plane for applications and owner-operated
models. Its job protocol and worker boundary are designed to expand toward
independently operated model capacity without making private deployments more
complex. Workers perform model inference only. They do not execute arbitrary
code or act as autonomous agents.

## Foundation

- Durable, schema-constrained jobs with idempotency, leases, and retries.
- Outbound-only workers beside OpenAI-compatible model endpoints.
- Per-device Ed25519 identity, signed requests, and replay prevention.
- Tenant-scoped applications, definitions, jobs, tokens, and workers.
- Owner-controlled identity reset and worker revocation.
- Owner-assigned worker trust tiers and application routing policies.
- Organization worker pools for explicit workload boundaries.
- Expiring, one-use enrollment grants and worker identity audit events.

## Shared worker pools

- Model, capability, privacy, and data-residency constraints.
- Signed worker manifests and auditable identity events.
- Routing based on owner-defined trust, not only advertised capabilities.
- Optional, timezone-aware provider participation schedules.
- Consumers select pools without learning individual worker identities.

## Independent worker network

- Provider profiles and independently operated worker enrollment.
- Verifiable offers covering model, capacity, price, and policy.
- Usage accounting, provider rewards, platform fees, settlement, reputation,
  disputes, and abuse controls.
- Optional federation or peer discovery after the centralized protocol is proven.

Cross-organization routing, payments, public discovery, hardware attestation,
and confidential inference are intentionally deferred. They should be added as
opt-in layers rather than prerequisites for a private AI Hub installation.

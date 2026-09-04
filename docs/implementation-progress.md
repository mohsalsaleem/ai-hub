# AI Hub implementation progress

This document tracks delivery against the direction in
[product-direction.md](product-direction.md). Update it when a task starts,
lands, changes scope, or is deliberately deferred.

## Current milestone

### Milestone 5: Metering and rewards

Status: Immutable execution metering verified locally, pending commit

| Work item | Status | Notes |
| --- | --- | --- |
| Per-attempt execution record | Complete locally | Every claim, retry, and lease expiry receives separate outcome evidence. |
| Canonical usage report | Complete locally | Token aliases are normalized, totals are recomputed, and values are bounded. |
| Finalized immutability | Complete locally | Terminal evidence cannot be updated or destroyed through application models. |
| Consumer usage view | Complete locally | Run details show attempts, tokens, and duration without provider worker or model identity. |
| Provider usage view | Complete locally | Hosting shows 30-day contribution and recent executions without consumer payloads. |
| Platform usage view | Complete locally | Operations shows shared usage without prompts or responses. |
| Credits and balances | Pending | Starts only after execution records are verified. |
| Pricing and platform share | Deferred | Requires explicit charging policy and ledger reconciliation. |
| Payments and payouts | Deferred | Begins only after internal credits reconcile reliably. |

### Milestone 4: Shared pools

Status: Complete and committed

| Work item | Status | Notes |
| --- | --- | --- |
| Provider-owned shared pool | Complete | A provider explicitly marks a pool shared; it is not publicly discoverable. |
| Consumer access grants | Complete | Pool owners grant and revoke access by organization slug. |
| Consumer pool selection | Complete | Granted pools appear in application settings without exposing provider workers. |
| Cross-organization claims | Complete | Shared workers can claim only granted runs in their own shared pools. |
| Cross-organization trust | Complete | Consumers must explicitly accept external or verified provider capacity. |
| Scoped task-definition access | Complete | A worker can fetch a consumer definition only while holding its active lease. |
| Grant revocation | Complete | Revocation clears future application routing and leaves queued run snapshots bound. |
| Platform operator authorization | Complete locally | Separate identities and sessions cannot be reached through tenant credentials. |
| Isolated operator console | Complete locally | Cross-tenant metadata is separated from tenant navigation and excludes run payloads. |
| Shared pool review | Complete locally | Pending pools require approval; suspension and revocation stop cross-organization claims. |
| Operator audit history | Complete locally | Shared pool decisions create immutable actor and target records. |
| Multi-provider pools | Deferred | The first slice keeps each shared pool and its capacity under one provider organization. |
| Platform-managed pools | Deferred | Operator controls exist, but platform-owned pool membership is not implemented. |

## Decisions recorded

- AI Hub routes model inference only. It does not execute arbitrary code and
  does not contain an agent concept.
- Applications own task definitions and runs.
- Consumers select worker pools and do not select or inspect individual
  workers.
- Workers are provider-facing infrastructure managed through Hosting.
- Activity is the organization-wide view across application runs.
- `Job` remains the internal model and protocol term during compatibility;
  Run is the console term.
- Provider participation, scheduling, shared pools, metering, rewards, and
  platform fees remain later milestones.
- Routing policy is immutable for an individual run. Application setting
  changes apply only to runs submitted afterward.
- Routing evidence stores no run input, output, or model response and is capped
  at 4 KB per decision.
- Shared participation is an explicit provider preference only. It does not
  weaken the current organization boundary or grant access to shared pools.
- Availability policy lives in AI Hub and does not require a worker release.
- Shared pools are grant-only and provider-owned in the first release. They are
  not listed in a public marketplace.
- A provider worker marked owner-operated is still external to a consumer.
  Cross-organization runs must opt into external or verified provider trust.
- Consumer responses expose the selected pool but never worker or machine
  identity.

## Verification log

| Date | Verification | Result |
| --- | --- | --- |
| 2026-09-04 | Application section navigation | Real routes and active states verified locally. |
| 2026-09-04 | Rails tests before Milestone 1 navigation pass | 50 tests, 238 assertions, no failures. |
| 2026-09-04 | RuboCop before Milestone 1 navigation pass | 101 files, no offenses. |
| 2026-09-04 | Milestone 1 Rails tests | 52 tests, 259 assertions, no failures. |
| 2026-09-04 | Milestone 1 RuboCop | 101 files, no offenses. |
| 2026-09-04 | Local browser verification | Overview, Activity, Hosting, Settings, application Runs, and application Settings routes verified. |
| 2026-09-04 | Milestone 1 commit | `71deab6 Complete product structure milestone` |
| 2026-09-04 | Milestone 2 targeted routing tests | 20 tests, 85 assertions, no failures. |
| 2026-09-04 | Milestone 2 Rails tests | 57 tests, 279 assertions, no failures. |
| 2026-09-04 | Milestone 2 RuboCop | 106 files, no offenses. |
| 2026-09-04 | Milestone 2 local browser check | Consumer-safe pool and queued routing reason verified on run detail. |
| 2026-09-04 | Milestone 2 final Rails tests | 59 tests, 289 assertions, no failures. |
| 2026-09-04 | Milestone 2 final RuboCop | 107 files, no offenses. |
| 2026-09-04 | Milestone 2 commit | `83ca94d Add explainable pool routing boundary` |
| 2026-09-04 | Milestone 3 provider policy tests | 70 tests, 326 assertions, no failures. Active leases remain completable after pause. |
| 2026-09-04 | Milestone 3 RuboCop | 109 files, no offenses. |
| 2026-09-04 | Milestone 3 local browser check | Hosting configuration, available state, pause, and resume verified. |
| 2026-09-04 | Milestone 3 commit | `7d0b028 Add provider participation controls` |
| 2026-09-04 | Shared-pool routing tests | 80 tests, 370 assertions, no failures. |
| 2026-09-04 | Shared-pool RuboCop | 114 files, no offenses. |
| 2026-09-04 | Shared-pool Brakeman | 79 checks, no security warnings. |
| 2026-09-04 | Operator foundation Rails tests | 94 tests, 451 assertions, no failures. |
| 2026-09-04 | Operator foundation RuboCop | 128 files, no offenses. |
| 2026-09-04 | Operator foundation Brakeman | 79 checks, no security warnings. |
| 2026-09-04 | Operator console browser check | Separate sign-in, isolated navigation, pool review metadata, tenant return path, and payload exclusion verified locally. |
| 2026-09-04 | Shared-pool local browser check | Provider grant management and consumer pool selection verified without worker disclosure. |
| 2026-09-04 | Shared-pool commit | `246d3b0 Add granted shared pool routing` |
| 2026-09-04 | Operator foundation commit | `64f038a Add isolated platform operator control` |
| 2026-09-04 | Metering Rails tests | 106 tests, 535 assertions, no failures. |
| 2026-09-04 | Metering RuboCop | 134 files, no offenses. |
| 2026-09-04 | Metering Brakeman | 79 checks, no security warnings. |
| 2026-09-04 | Metering browser check | Consumer run usage, provider contribution, platform shared usage, payload boundaries, and browsable docs verified locally. |

## Next work

1. Commit and deploy metering with worker 0.3.
2. Define charging policy for success, failure, retry, and lease expiry.
3. Add an append-only internal credit ledger with reconciliation checks.

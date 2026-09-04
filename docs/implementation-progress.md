# AI Hub implementation progress

This document tracks delivery against the direction in
[product-direction.md](product-direction.md). Update it when a task starts,
lands, changes scope, or is deliberately deferred.

## Current milestone

### Milestone 3: Provider participation

Status: First slice complete locally, pending review and commit

| Work item | Status | Notes |
| --- | --- | --- |
| Private and shared participation modes | Complete | Shared mode records provider intent but does not enable cross-organization routing yet. |
| Manual pause and resume | Complete | Pausing stops new claims while active leases can still complete. |
| Timezone-aware availability | Complete | Providers select days, timezone, and an optional daily window. Overnight windows are supported. |
| Concurrency limit | Complete | Workers claim only below their configured active-run limit. |
| Provider capacity states | Complete | Hosting distinguishes available, busy, paused, scheduled offline, offline, and revoked workers. |
| Routing diagnosis | Complete | Queued runs explain paused, scheduled, busy, offline, incompatible, or unavailable capacity. |
| Hosting controls | Complete | Provider configuration is managed from each worker card. |
| Usage limits | Deferred | Requires the metering model planned before shared paid capacity. |
| Served-run detail | Deferred | The current card shows the served count. A privacy-safe provider activity view belongs with shared pools. |

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

## Next work

1. Review the provider controls in Hosting.
2. Commit and deploy the first Milestone 3 slice.
3. Define the shared-pool access grant and provider privacy boundary.
4. Design usage metering before adding provider usage limits or rewards.

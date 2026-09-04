# AI Hub implementation progress

This document tracks delivery against the direction in
[product-direction.md](product-direction.md). Update it when a task starts,
lands, changes scope, or is deliberately deferred.

## Current milestone

### Milestone 2: Pool routing boundary

Status: Complete locally, pending review and commit

| Work item | Status | Notes |
| --- | --- | --- |
| Run routing policy snapshot | Complete | Pool, pool name, and minimum trust are copied onto a run when it is submitted. |
| Pool and trust claim boundary | Complete | Claims use the run snapshot instead of mutable application settings. |
| Capability eligibility | Complete | Executor and declared task requirements remain mandatory. |
| Bounded routing evidence | Complete | One queued record plus one selected record per allowed attempt, with a 4 KB evidence limit. Expired final leases become dead. |
| Durable selection evidence | Complete | Internal evidence snapshots pool and worker identity even if records are later removed. |
| Consumer-safe routing status | Complete | API and run detail expose pool and general reason, never worker identity. |
| Queued-run diagnosis | Complete | Explains missing, inactive, untrusted, incompatible, or offline capacity. |
| Platform operator diagnostics | Deferred | The evidence model is ready; a separate platform administration surface is a later milestone. |

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

## Next work

1. Review and commit the Milestone 2 routing boundary.
2. Deploy the migrations and verify existing application and worker tokens.
3. Define the platform operator surface before exposing internal selection
   evidence in the console.
4. Begin Milestone 3 with provider participation modes and availability.

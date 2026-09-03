# AI Hub implementation progress

This document tracks delivery against the direction in
[product-direction.md](product-direction.md). Update it when a task starts,
lands, changes scope, or is deliberately deferred.

## Current milestone

### Milestone 1: Product structure

Status: Complete locally, pending commit and deployment

| Work item | Status | Notes |
| --- | --- | --- |
| Stable application section routes | Complete | Overview, Task definitions, Runs, and Settings use real Rails routes. |
| Simplified sidebar | Complete | Overview, Applications, Activity, and owner-only Hosting are primary. Documentation and Settings sit at the bottom. |
| Jobs renamed to Runs in the console | Complete | Database model, internal routes, and API remain `Job` for compatibility. |
| Organization-wide Activity | Complete | Uses the existing organization-scoped job index without exposing worker identity. |
| Provider-facing Hosting | Complete | Uses existing worker and pool management while the provider domain remains small. |
| Generic Settings entry point | Complete | `/settings` opens Organization as the first settings area. |
| Consumer worker privacy | Complete | Application and Activity views expose pools and runs, not worker identity. Hosting requires owner access. |

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

## Verification log

| Date | Verification | Result |
| --- | --- | --- |
| 2026-09-04 | Application section navigation | Real routes and active states verified locally. |
| 2026-09-04 | Rails tests before Milestone 1 navigation pass | 50 tests, 238 assertions, no failures. |
| 2026-09-04 | RuboCop before Milestone 1 navigation pass | 101 files, no offenses. |
| 2026-09-04 | Milestone 1 Rails tests | 52 tests, 259 assertions, no failures. |
| 2026-09-04 | Milestone 1 RuboCop | 101 files, no offenses. |
| 2026-09-04 | Local browser verification | Overview, Activity, Hosting, Settings, application Runs, and application Settings routes verified. |

## Next work

1. Review the Milestone 1 console locally.
2. Commit and deploy the product structure before changing routing behavior.
3. Begin Milestone 2 with the worker pool boundary and routing evidence.

# AI Hub product direction

## Purpose

AI Hub connects applications to privately hosted language models through an
outbound-only worker. It lets people use their own models privately and, when
they choose, make otherwise idle model capacity available to other users.

AI Hub routes model inference. It is not a general compute platform, an agent
platform, or a remote code execution system. Workers receive declarative model
requests, send them to a configured model, and return the response.

The product begins as a simple private model hub. Shared model capacity,
metering, rewards, and platform fees will be added only after routing and trust
boundaries are reliable.

## People using the platform

A person or organization can use AI Hub in more than one way.

### Consumer

A consumer connects an application, publishes task definitions or model
profiles, submits runs, and chooses an allowed worker pool. Consumers do not
need to know which individual worker handles a run.

### Provider

A provider runs a worker beside a local model. The provider chooses which model
capacity to share, when it is available, and what limits apply. A provider may
keep all workers private and never participate in shared pools.

### Platform operator

The platform operator manages shared pools, routing policy, trust, abuse
controls, metering, and eventually settlement. Pool membership and individual
worker selection are platform concerns rather than consumer concerns.

These are capabilities, not exclusive account types. The same organization can
consume model responses and provide model capacity.

## Product concepts

### Application

An application is the consumer integration boundary. It owns API credentials,
task definitions, runs, and routing preferences.

### Task definition

A task definition contains model instructions, typed input and output
contracts, and capability requirements. It belongs to one application.

### Run

Run is the user-facing name for a model request and its lifecycle. The current
database and protocol may continue using `Job` internally while the product
uses Run in the console.

### Worker

A worker is a lightweight service running beside a model endpoint. It maintains
an outbound connection to AI Hub, advertises supported model capabilities,
claims eligible runs, invokes the local model, and returns responses.

A worker is not an agent. It cannot execute arbitrary application logic, tools,
or uploaded code.

For the first shared-capacity release, one worker registration represents one
routable model endpoint. A machine may run multiple workers for isolation or
multiple models, but multiple workers should not represent the same capacity
because that would distort availability and usage accounting. Supporting
multiple model endpoints behind one worker can be added later without exposing
that complexity to consumers.

### Worker pool

A worker pool is the consumer-facing routing boundary. A pool contains
compatible model capacity from one or more workers. Consumers select pools,
not individual workers.

A pool can initially be private to an organization. Shared pools can later
contain participating workers from multiple providers. Pool membership and
worker identity remain hidden from consumers.

### Activity

Activity is the organization-wide operational view. It aggregates runs across
applications without changing their ownership. It can later include router
decisions, worker events, retries, and metering records.

## Ownership and visibility

```text
Organization
├── Applications
│   ├── Credentials
│   ├── Task definitions
│   ├── Runs
│   └── Routing preferences
│
├── Hosted workers
│   ├── Model configuration
│   ├── Availability
│   └── Participation policy
│
└── Settings
```

The consumer flow exposes a worker pool and its service characteristics. It
does not expose worker names, provider identity, machine details, addresses, or
other routing internals.

Providers can inspect only their own workers and served runs. Platform
operators can inspect pool membership and the routing evidence required to
operate the service.

## Request flow

```text
Application submits a run
          |
          v
Application routing policy selects an allowed pool
          |
          v
AI Hub filters eligible workers inside the pool
          |
          v
AI Hub selects one available worker
          |
          v
Worker invokes its configured model and returns the response
```

The first router should be deterministic and explainable. Eligibility checks
should include organization or pool access, worker trust, declared
capabilities, task requirements, availability, and lease state. Load,
reliability, affinity, cost, and other scoring algorithms can be introduced
after the basic selection boundary is proven.

## Provider participation

Shared participation must be optional. A provider should eventually control:

- Private-only or shared participation
- Days, hours, and timezone
- Manual pause and resume
- Maximum concurrent runs
- Usage limits
- Which models or workloads may be served
- Whether local use takes priority

Worker status must distinguish expected and unexpected absence:

- Available
- Busy
- Scheduled offline
- Manually paused
- Unexpectedly offline

Availability schedules belong to AI Hub policy, but the worker must also stop
claiming shared work when its local participation policy says it is unavailable.

## Product navigation

The tenant console should use a small set of durable destinations:

```text
Overview
Applications
Activity
Hosting        shown when the organization provides model capacity

Documentation
Settings
```

An application contains:

```text
Overview
Task definitions
Runs
Settings
  Worker pool
  API credentials
```

Hosting contains:

```text
Workers
Models
Availability
```

Settings contains:

```text
Organization
Members
Access
```

The platform operator will eventually need a separate administration surface
for providers, pool membership, router health, abuse controls, and settlement.
Those controls should not leak into the consumer application experience.

## Commercial direction

Providers may eventually earn from successful model inference served through
shared pools. AI Hub will retain a transparent platform share from billable
usage.

Payments are not part of the first shared-routing release. Before introducing
money, AI Hub needs trustworthy usage records covering the run, consumer,
provider, pool, measured usage, outcome, and routing decision. A credit ledger
can validate this accounting model before real payment collection and payouts.

## Initial scope

The next release should remain deliberately small:

- Applications own task definitions and runs.
- Consumers select a worker pool and never select an individual worker.
- Providers manage only their own workers.
- Workers remain outbound-only and perform model inference only.
- Private organization pools continue to work.
- A run records enough routing evidence to explain why a worker was selected.
- SQLite and a single Rails Hub instance remain supported.

The release does not include payments, public marketplace discovery, arbitrary
router plugins, federation, NATS, hardware attestation, or general compute.

## Delivery plan

### Milestone 1: Product structure

- Apply the new console navigation.
- Move task definitions and runs under applications.
- Rename Jobs to Runs in user-facing copy while keeping protocol compatibility.
- Add Activity as the cross-application run view.
- Add Hosting as the provider-facing home for workers.
- Turn Settings into a section beginning with Organization.

Acceptance criteria:

- A consumer can manage an application without seeing individual workers.
- Every application section has a stable route and active navigation state.
- A provider can reach worker management through Hosting.
- Existing application and worker credentials remain valid.

### Milestone 2: Pool routing boundary

- Make pool selection part of application settings.
- Keep pool membership visible only to providers and platform operators.
- Record the selected pool and worker on each run.
- Add a bounded router decision record with eligibility and selection reasons.
- Preserve existing trust and capability checks.

Routing evidence is deliberately compact. A run records one queued decision
when submitted and at most one selected decision per allowed attempt. Evidence
contains the policy checks and required capabilities, not the input, output, or
model response. Consumer APIs expose the pool and a general routing explanation
but never the selected worker identity.

Acceptance criteria:

- A run is claimed only by a compatible worker in the selected pool.
- A consumer response never exposes worker identity.
- Operators can explain why a run was routed or remained queued.

### Milestone 3: Provider participation

- Add private and shared participation modes.
- Add timezone-aware availability schedules and manual pause.
- Represent scheduled offline separately from unexpected offline.
- Add concurrency and basic usage limits.
- Add provider views for submitted capacity and served runs.

The first participation slice keeps routing organization-local. A provider can
mark capacity as shared, but this records intent only until shared pool grants
exist. AI Hub enforces manual pause, local-time availability windows, and
concurrency limits before a worker can claim a run. Pausing affects new claims
and does not invalidate a lease that is already running.

Acceptance criteria:

- A private worker never receives shared runs.
- A shared worker receives work only during its allowed schedule.
- Disabling participation stops new shared claims without interrupting an active
  lease.

### Milestone 4: Shared pools

- Introduce provider access to platform-managed pools.
- Add cross-organization pool grants without exposing worker identities.
- Add fair, deterministic routing across available providers.
- Add privacy, retention, rate-limit, and abuse controls required for unknown
  operators.

The first shared-pool slice uses provider-owned pools and explicit consumer
organization grants. A shared pool is not publicly discoverable. The provider
owns every worker in that pool, while a granted consumer sees only the pool as
a routing target. Cross-organization claims require the worker to opt into
shared participation and the application to accept external or verified
provider trust. Multi-provider and platform-managed pools follow after a
separate platform operator role exists.

Acceptance criteria:

- Consumers can use an approved shared pool without joining the provider's
  organization.
- Providers can see their own contribution without seeing private consumer
  configuration.
- Cross-organization access is denied unless an explicit grant exists.

### Milestone 5: Metering and rewards

- Record immutable usage and outcome evidence per run.
- Introduce internal credits and provider balances.
- Calculate provider share and AI Hub platform share.
- Add consumer spending limits and provider earning reports.
- Add payments and payouts only after reconciliation is reliable.

Acceptance criteria:

- Every balance change can be traced to an immutable run and ledger entry.
- Failed or rejected runs follow an explicit charging policy.
- Consumer charges, provider earnings, and platform fees reconcile exactly.

## Immediate implementation sequence

1. Complete the navigation and application page restructuring already started.
2. Rename user-facing Jobs to Runs and introduce the Activity route.
3. Move worker management into a Hosting section.
4. Put application pool selection and credentials under application Settings.
5. Add routing decision evidence before changing the current selection
   algorithm.
6. Add provider participation and scheduling after the pool boundary is clear.

This sequence improves the product model without prematurely building the
shared marketplace or payment system.

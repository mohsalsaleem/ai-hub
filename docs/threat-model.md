# AI Hub threat model

AI Hub connects applications to workers that may be operated outside the Hub's
trusted network. An application is not trusted by a worker merely because the
Hub accepted its job.

## Security properties

- Workers initiate every network connection. A model host needs no inbound port.
- Jobs contain declarative instructions and JSON data, never application code.
- A worker is scoped to one organization and receives only compatible jobs.
- An enrolled worker proves possession of its device key on every request.
- Timestamps and single-use nonces limit replay of captured requests.
- A job lease prevents a former worker from overwriting a reassigned job.
- Inputs, outputs, tokens, private keys, and model prompts are secrets.

## Current trust boundaries

The Hub is trusted with plaintext job inputs and outputs, routing, and identity
records. The worker operator is trusted with every job routed to that worker.
TLS provides confidentiality and server authentication. Device signatures
authenticate a worker but do not make an untrusted model host confidential.

## Current controls

| Threat | Control |
| --- | --- |
| Stolen enrollment token | One worker per token; rotate to reset and re-enroll |
| Replayed runtime request | Ed25519 signature, five-minute timestamp window, stored nonce |
| Forged worker label | Database identity comes from the key; reported ID is display metadata |
| Cross-tenant claiming | Organization-scoped claim query and definition lookup |
| Worker dies during a job | Expiring lease and bounded retry budget |
| Application attempts code execution | Fixed executors; definitions carry instructions and schemas only |
| Oversized payload | Request and definition size limits |

## Known gaps

- The enrollment bearer token remains a recovery credential and must be secret.
- Private keys are file-protected but are not yet stored in platform key storage.
- Nonce cleanup occurs during authentication and should become scheduled work at scale.
- AI Hub does not yet attest worker hardware, model, software build, or operator identity.
- Provider isolation, content policy, payment fraud, confidential inference, and disputes remain future work.

## Next security milestones

1. Replace reusable enrollment tokens with expiring, one-use enrollment grants.
2. Record identity events for enrollment, rotation, revocation, and failures.
3. Use platform key storage where supported.
4. Add signed model manifests and owner trust policies before cross-organization routing.
5. Complete a focused security review before accepting jobs from unknown operators.

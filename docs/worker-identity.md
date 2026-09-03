# Worker identity protocol

Each official worker creates an Ed25519 key pair on first boot. The private key
remains in the worker state directory with mode `0600`. AI Hub stores only the
public key and its SHA-256 fingerprint.

The owner first issues a worker enrollment grant in the console. It is displayed
once, expires after 24 hours, and is consumed by successful enrollment. The
worker uses that grant to enroll its public key and proves possession by signing:

```text
aihub-worker-enrollment/v1\n<key fingerprint>
```

After enrollment, the bearer token is no longer accepted by runtime endpoints.
Every runtime request includes the key fingerprint, Unix timestamp, random
nonce, and an Ed25519 signature over:

```text
<HTTP METHOD>\n<path and query>\n<timestamp>\n<nonce>\n<SHA-256 request-body digest>
```

AI Hub accepts a timestamp within five minutes and records each nonce for ten
minutes. A repeated nonce is rejected. Rotating the worker token removes the
old public key, revokes unused grants, and creates a new one-use grant.

The official worker records successful enrollment locally as a digest of the
grant, never the grant itself. An upgraded worker with no local marker first
tries its existing signed identity. It enrolls only when the Hub does not know
that key. This allows older enrolled workers to upgrade without requiring a new
grant.

This proves that requests came from possession of an enrolled key. It does not
prove who owns the machine, which model is running, or whether the worker
retained job data. Provider identity and hardware or model attestation are
separate trust layers.

AI Hub records lifecycle events for grant issuance, enrollment, identity reset,
revocation, trust changes, and pool changes. Events contain no private keys or
plaintext credentials.

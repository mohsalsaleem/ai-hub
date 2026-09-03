# Worker identity protocol

Each official worker creates an Ed25519 key pair on first boot. The private key
remains in the worker state directory with mode `0600`. AI Hub stores only the
public key and its SHA-256 fingerprint.

The owner first issues a worker token in the console. The worker uses that token
to enroll its public key and proves possession by signing:

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
old public key and requires a fresh enrollment.

This proves that requests came from possession of an enrolled key. It does not
prove who owns the machine, which model is running, or whether the worker
retained job data. Provider identity and hardware or model attestation are
separate trust layers.

# Security policy

Please do not publish suspected vulnerabilities in a public issue. Until a
repository security contact is configured, report them privately to the
repository owner.

AI Hub never intends to execute application-supplied code. Task definitions
contain instructions and JSON Schemas only. Treat application tokens, worker
tokens, model inputs, and model outputs as secrets. Production deployments
must use HTTPS, a strong `AI_HUB_ADMIN_PASSWORD`, and durable private storage.

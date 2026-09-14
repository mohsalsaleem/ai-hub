# OpenAI-compatible integration

AI Hub exposes a deliberately small OpenAI-compatible text API over its durable
job protocol. Applications use familiar request and response shapes while the
Hub continues to lease work to outbound-only workers. No inbound connection to
the model host is required.

## Set up an application

1. Create an application in the AI Hub console and copy its token when shown.
2. Open the application and choose **Add OpenAI model**.
3. Enter an application-scoped key such as `assistant.general`, keep version 1,
   and write the system instructions for this model profile.
4. Publish the profile. AI Hub supplies the standard chat schemas.
5. Confirm that an online worker advertises the `chat_completion` capability.

Published model profiles are immutable task definitions. Their public model ID
is `key@version`, for example `assistant.general@1`. A request may omit the
version and use `assistant.general`; AI Hub then selects the latest active
version belonging to that application.

The application token can only list and invoke its own model profiles. The
model name configured on the worker with `AI_MODEL` remains the actual local
inference model; an AI Hub model ID selects instructions and behavior, not an
arbitrary model on the worker host.

## Configure a client

Use the application token as the API key and the AI Hub origin followed by
`/v1` as the client base URL.

Python:

```python
from openai import OpenAI

client = OpenAI(
    api_key="aih_...",
    base_url="https://aihub.example.com/v1",
)

response = client.chat.completions.create(
    model="assistant.general@1",
    messages=[{"role": "user", "content": "Summarize this note."}],
)
print(response.choices[0].message.content)
```

JavaScript:

```javascript
import OpenAI from "openai";

const client = new OpenAI({
  apiKey: "aih_...",
  baseURL: "https://aihub.example.com/v1",
});

const response = await client.responses.create({
  model: "assistant.general@1",
  input: "Summarize this note.",
});
console.log(response.output_text);
```

Keep tokens in environment variables or a secret manager rather than source
control. Production clients must use HTTPS.

## Supported endpoints

| Endpoint | Behavior |
| --- | --- |
| `GET /v1/models` | Lists active chat model profiles for the application. |
| `POST /v1/chat/completions` | Waits synchronously for a text completion. |
| `POST /v1/responses` | Waits synchronously, or returns immediately when `background` is true. |
| `GET /v1/responses/:id` | Retrieves a durable background response. |

Text `system`, `developer`, `user`, and `assistant` messages are supported.
The compatibility layer forwards `temperature`, `top_p`, `stop`, and token
limits. It also forwards `response_format` with `type: "json_schema"` to the model
worker, preserving its `name`, `description`, `strict`, and `schema` fields.
The local inference server must support JSON-schema output. Chat Completions
returns `prompt_tokens`, `completion_tokens`, and `total_tokens` usage fields.
Responses requests also accept a top-level `instructions` string.

Existing published model profiles are immutable. To use `response_format`,
publish a new profile version with the updated default chat input schema;
older closed schemas reject the new parameter rather than silently ignoring it.
Upgrade workers as well as the Hub before enabling this option.

For local servers that support chat-template options, the worker accepts
`AI_MODEL_CHAT_TEMPLATE_KWARGS` as a JSON object. For example, Qwen deployments
can use `AI_MODEL_CHAT_TEMPLATE_KWARGS='{"enable_thinking":false}'` to keep
structured extraction within its generation budget. This is a worker-side
setting, not a client-supplied parameter. It is omitted by default; confirm
support in the inference server before configuring it.

Streaming, tool calls, images, files, audio, embeddings, conversation objects,
and `previous_response_id` are not supported yet. Requests for streaming fail
explicitly instead of silently returning a non-streaming response.

## Synchronous requests

Synchronous endpoints wait for the internal job for up to 60 seconds by
default. Configure the Hub with:

```text
AI_HUB_OPENAI_SYNC_TIMEOUT=60
```

The accepted range is 1 to 300 seconds. Workers keep an outbound long-poll claim
open and normally receive a queued job within 500 ms. The long-poll duration is
not an additional pickup delay.

If Chat Completions exceeds the synchronous timeout, AI Hub returns a gateway
timeout with the durable internal job ID in the message. The job is not
cancelled and remains visible in the operations console. For workloads that may
run longer than the HTTP timeout, use a background Responses request.

## Background responses

Create a durable request:

```bash
curl -X POST https://aihub.example.com/v1/responses \
  -H 'Authorization: Bearer aih_...' \
  -H 'Content-Type: application/json' \
  -d '{
    "model": "assistant.general@1",
    "input": "Write a short release note.",
    "background": true
  }'
```

The returned `id` is the durable AI Hub job ID. Retrieve it with the same
application token:

```bash
curl https://aihub.example.com/v1/responses/job_... \
  -H 'Authorization: Bearer aih_...'
```

The status is `in_progress` until the worker completes the job, then
`completed`. Completed responses include both the standard output message and
the convenient `output_text` field.

## Idempotency and failures

Send an `Idempotency-Key` header when a caller may retry a request. Reusing the
same key with identical parameters returns the existing job. Reusing it with
different parameters returns `409 idempotency_conflict`.

Worker failures use an OpenAI-shaped error envelope. AI Hub retains the job,
attempt count, worker assignment, and underlying error in the tenant console.
Application and organization isolation is identical to the native job API.

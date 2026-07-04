---
name: al-integration
description: Design, implement, and review Microsoft Dynamics 365 Business Central AL integrations over HTTP/HTTPS, OData, and REST APIs (including Business Central API pages). Use when implementing HttpClient communication, authentication, request/response mapping, OData query patterns, pagination, retries, idempotency, and integration error handling for inbound or outbound flows.
---

# AL Integration

Use this workflow.

1. Apply baseline conventions first.
- Use `$al-conventions` as baseline for naming, structure, and safe error messaging.

2. Confirm integration scope.
- Confirm AL project context (`app.json`, `.al` files, or AL launch configuration).
- Identify direction: outbound call, inbound API exposure, or both.
- Identify protocol and shape: REST JSON, OData, API page, webhook, batch sync.
- Define contract inputs, outputs, ownership, and idempotency key.

3. Define extension-safe architecture.
- Separate request mapping, transport, and business processing.
- Use interfaces for transport and message handlers when multiple providers/endpoints exist.
- Add positive integration events at pre/post processing boundaries for additive changes such as enriching request context, diagnostics, or mapping details.
- Do not use generic `OnBefore...IsHandled` events to bypass sending, validation, retry, or response handling; use a transport/message handler interface implementation when behavior must be replaced.
- Keep standard object changes extension-based (extensions + subscribers).

4. Implement outbound HTTP/HTTPS flow.
- Build requests with `HttpClient`, `HttpRequestMessage`, and `HttpContent`.
- Centralize base URL, endpoint paths, headers, timeout, and auth setup.
- Use HTTPS endpoints and avoid logging secrets/tokens.
- Map payloads with `JsonObject`/`JsonToken` and explicit field handling.
- Validate status code and parse structured error payloads.

5. Implement OData/API flow details.
- For OData consumption, design `$filter`, `$select`, `$top`, and pagination handling (`@odata.nextLink`/skip tokens).
- For external API consumption, implement pagination contract (`next`, cursor, or page/size).
- For BC exposure, prefer API pages with versioned routes and stable keys.
- Keep API contracts backward compatible when evolving schemas.

7. Cover observability and operations.
- Capture request/response metadata (endpoint, method, status, duration).
- Keep setup validation centralized before processing attempts.
- Persist diagnostics needed for replay and troubleshooting without exposing secrets.

8. Coordinate with other AL skills.
- Use `$al-object-builder` when creating API pages, setup tables, or integration codeunits.
- Use `$al-performance` for deeper queue/throughput optimization.
- Use `$al-testing` for integration-focused test codeunits and transport mocking patterns.
- Use `$al-upgrades` when integration changes require upgrade codeunits or migrations.

9. Validate and report.
- Summarize endpoints/protocols, auth model, and object boundaries.
- List retry, idempotency, pagination, and error-handling decisions.
- Call out unresolved assumptions and required test scenarios.

## References

- Read `references/integration-checklist.md` for review-time checks.
- Read `references/integration-patterns.md` for starter patterns.

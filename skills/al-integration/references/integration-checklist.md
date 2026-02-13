# Integration Checklist

## Scope and Contract

- Define integration direction: outbound, inbound API exposure, or both.
- Define protocol per endpoint: REST, OData, webhook, BC API page.
- Define request/response schema, ownership, and idempotency key.

## Security and Setup

- Use HTTPS endpoints and centralize base URL and timeout setup.
- Store tokens/secrets securely and do not log sensitive values.
- Validate setup before call execution (endpoint, auth mode, feature flags).

## HTTP Request/Response Handling

- Build requests with explicit method, URI, headers, and content type.
- Serialize/deserialize payloads with explicit field mapping.
- Handle non-2xx responses with structured diagnostics.

## OData and API Specifics

- For OData consumption, use selective fields and server-side filtering.
- Handle pagination via `@odata.nextLink`, skip token, cursor, or page/size.
- For BC exposure, prefer versioned API pages and stable keys.

## Error Handling

- Use labels for user-visible error messages.
- Persist operational error details for diagnostics.
- Keep HTTP/OData failure handling centralized and consistent.

## Performance and Scalability

- Keep payloads small (`$select`, narrow API payload contracts).
- Load only required fields (`SetLoadFields`) before reads.
- Batch and schedule processing through job queue runners when needed.

## Extensibility

- Use interfaces for transport and message handlers.
- Add integration events around critical extension points.
- Keep handlers small and focused by responsibility.

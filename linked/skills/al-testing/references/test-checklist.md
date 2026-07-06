# Test Checklist

## Project and File Placement

- Test code lives in Test project or designated test folders only.
- Test folder structure mirrors App feature structure.
- Test `app.json` depends on App package; App does not depend on Test.

## Test Design

- Test names follow Given/When/Then semantics.
- Each test validates one behavior concern.
- Success and failure paths are both covered where relevant.
- Edge cases are included for key business rules.

## Setup and Data

- Prefer `Library - *` codeunits for creating data and posting documents.
- Keep test setup deterministic and explicit.
- Avoid sharing mutable state across tests.

## Assertions

- Use `Assert` codeunit for clear, direct assertions.
- Assert outcomes that matter to business behavior, not only technical side effects.
- Ensure expected values are explicit and readable.

## Maintainability

- Keep helper procedures focused and reusable.
- Remove duplicate setup logic by extracting common helpers.
- Keep tests isolated, repeatable, and order-independent.

## Gotchas

- **`Codeunit.Run` cannot be driven from a test that has pending uncommitted writes.**
  It runs in the *same* transaction, so an inner error surfaces as
  "The transaction is stopped..." instead of the expected caught `false` return.
  Call the target logic directly (e.g. expose the entry point as `internal`, such
  as a `ProcessEntry` procedure) and assert on its result rather than going through
  `Codeunit.Run`.
- **A fresh/fabricated `HttpResponseMessage` reports `IsSuccessStatusCode = true`**
  (it defaults to a 2xx status) and AL exposes **no `HttpStatusCode` setter**. A mock
  transport that hands back a new `HttpResponseMessage` therefore drives the
  *success* path, not a failure path. To exercise failure handling, set the response
  body/headers your code inspects, or route through a real non-2xx source — don't
  assume a hand-built response can represent an error status.

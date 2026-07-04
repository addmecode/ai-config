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

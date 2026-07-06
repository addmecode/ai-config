# Core Checklist

## Style and Naming

- Use 2-space indentation.
- Use PascalCase for objects, procedures, and variables.
- Use descriptive names and avoid unclear abbreviations.
- Keep filenames in `<ObjectName>.<ObjectType>.al` format.

## Structure and Extensibility

- Organize by business feature, not by AL object type.
- Prefer event subscribers and integration events for extension points.
- Prefer positive, purpose-named events that let multiple subscribers add behavior without skipping base code.
- Avoid new `IsHandled`/handled patterns unless no better model exists; prefer interfaces or setup-driven implementation selection for replaceable behavior.
- If `IsHandled` is unavoidable, document the reason, skip only a small visible block, and do not bypass validation.
- Keep procedures focused and modular.

## Performance

- Filter early with `SetRange` and `SetFilter`.
- Use `SetLoadFields` before `Get` or `Find*`.
- Prefer set-based operations (`CalcSums`, `ModifyAll`) over loops when possible.
- Use temporary records, `Dictionary`, or `List` for transient operations.

## Errors and Messages

- Use label variables for user-facing messages.
- Add label comments for placeholders.
- Use `TryFunction` for recoverable failure paths.

## Streams and Blobs

- An `InStream`/`OutStream` is only a view over a backing buffer (a
  `Codeunit "Temp Blob"`). The stream is valid only while its backing object is
  alive.
- Do **not** create an `InStream`/`OutStream` from a **local** `Temp Blob` and
  return the stream — the Temp Blob is destroyed when the procedure returns, so
  later reads (e.g. `CopyStream`) see an empty buffer. Adding `var` to the stream
  parameter does nothing; the buffer is already dead.
- Pass the owning `Codeunit "Temp Blob"` through the call chain and create the
  `InStream`/`OutStream` only at the point of use, where the buffer is guaranteed
  alive. This is the canonical Microsoft BC pattern.

## App and Test Separation

- Keep business logic in App project folders.
- Create tests only when explicitly requested.
- Place tests in Test project folders and mirror App feature structure.

# Architecture Patterns

Use these patterns as architecture starters for AL solutions.

## Orchestrator + Handler Interface

Apply when a process has a stable flow but variable implementation details.

```al
interface IMonitorProcessor
{
  procedure Process(var IntegrationInbox: Record "Integration Inbox");
}

codeunit 50100 "Monitor Orchestrator"
{
  procedure Run(var IntegrationInbox: Record "Integration Inbox")
  var
    MonitorProcessor: Interface IMonitorProcessor;
  begin
    MonitorProcessor := ResolveProcessor(IntegrationInbox."Message Type");
    MonitorProcessor.Process(IntegrationInbox);
  end;

  local procedure ResolveProcessor(MessageType: Enum "Message Type"): Interface IMonitorProcessor
  begin
    // Resolve interface implementation for message type.
  end;
}
```

## Positive Integration Event Boundary

Apply when downstream extensions need controlled additive hooks.

```al
[IntegrationEvent(false, false)]
local procedure OnBeforeProcessInbox(var IntegrationInbox: Record "Integration Inbox")
begin
end;

procedure ProcessInbox(var IntegrationInbox: Record "Integration Inbox")
begin
  OnBeforeProcessInbox(IntegrationInbox);
  // Default process flow.
  OnAfterProcessInbox(IntegrationInbox);
end;

[IntegrationEvent(false, false)]
local procedure OnAfterProcessInbox(var IntegrationInbox: Record "Integration Inbox")
begin
end;
```

Use interfaces or setup-driven implementation selection when extensions must replace the process flow. Avoid generic `OnBefore...IsHandled` events because they skip base code, prevent normal multi-subscriber behavior, and are fragile during refactoring.

## Status-Driven Processing

Apply when background processing requires retries and operator visibility.

```al
local procedure MarkFailed(var IntegrationOutbox: Record "Integration Outbox"; ErrorText: Text)
var
  OutboxFailedLbl: Label 'Integration outbox failed: %1', Comment = '%1 = Error text';
begin
  IntegrationOutbox.Status := IntegrationOutbox.Status::Failed;
  IntegrationOutbox."Last Error" := CopyStr(ErrorText, 1, MaxStrLen(IntegrationOutbox."Last Error"));
  IntegrationOutbox."Attempt Count" += 1;
  IntegrationOutbox.Modify(true);

  Message(OutboxFailedLbl, ErrorText);
end;
```

## Upgrade-Safe Backfill Pattern

Apply when architecture introduces new persisted fields and existing records need defaults.

```al
local procedure BackfillNewMonitorFields()
var
  UpgradeTag: Codeunit "Upgrade Tag";
  MonitorEntry: Record "Monitor Entry";
  MonitorTransfer: DataTransfer;
begin
  if UpgradeTag.HasUpgradeTag(GetBackfillMonitorFieldsTag()) then
    exit;

  MonitorTransfer.SetTables(Database::"Monitor Entry", Database::"Monitor Entry");
  MonitorTransfer.AddConstantValue(true, MonitorEntry.FieldNo("Enabled"));
  MonitorTransfer.CopyFields();

  UpgradeTag.SetUpgradeTag(GetBackfillMonitorFieldsTag());
end;
```

## Architecture Decision Output Template

Use this concise template when presenting solution architecture.

1. Decision: chosen approach and rationale.
2. Object Plan: AL objects and file names by feature folder.
3. Event/Interface Plan: publishers, subscribers, and contracts.
4. Risks: top failure modes and mitigations.
5. Validation: test scenarios and performance checks.

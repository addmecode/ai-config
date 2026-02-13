# Upgrade Patterns

Use these snippets as implementation starters.

## Upgrade Codeunit Dispatch

```al
codeunit 50130 "Sample Upgrade"
{
  Subtype = Upgrade;

  trigger OnUpgradePerCompany()
  begin
    UpgradeSamplePerCompany();
  end;

  trigger OnUpgradePerDatabase()
  begin
    UpgradeSamplePerDatabase();
  end;

  local procedure UpgradeSamplePerCompany()
  begin
    // Implement per-company routine with upgrade tag guard.
  end;

  local procedure UpgradeSamplePerDatabase()
  begin
    // Implement per-database routine with upgrade tag guard.
  end;
}
```

## Upgrade Tag Guard

```al
local procedure UpgradeSamplePerCompany()
var
  UpgradeTag: Codeunit "Upgrade Tag";
begin
  if UpgradeTag.HasUpgradeTag(GetUpgradeSamplePerCompanyTag()) then
    exit;

  // Perform migration work.

  UpgradeTag.SetUpgradeTag(GetUpgradeSamplePerCompanyTag());
end;
```

## Tag Registration

```al
[EventSubscriber(ObjectType::Codeunit, Codeunit::"Upgrade Tag", 'OnGetPerCompanyUpgradeTags', '', false, false)]
local procedure RegisterPerCompanyTags(var PerCompanyUpgradeTags: List of [Code[250]])
begin
  PerCompanyUpgradeTags.Add(GetUpgradeSamplePerCompanyTag());
end;

[EventSubscriber(ObjectType::Codeunit, Codeunit::"Upgrade Tag", 'OnGetPerDatabaseUpgradeTags', '', false, false)]
local procedure RegisterPerDatabaseTags(var PerDatabaseUpgradeTags: List of [Code[250]])
begin
  PerDatabaseUpgradeTags.Add(GetUpgradeSamplePerDatabaseTag());
end;
```

## Safe Read Pattern

```al
if Customer.Get(CustomerNo) then begin
  Customer.Blocked := Customer.Blocked::" ";
  Customer.Modify(true);
end;
```

## DataTransfer Backfill Pattern

```al
local procedure BackfillNewFields()
var
  SampleTable: Record "Sample Table";
  SampleDataTransfer: DataTransfer;
begin
  SampleDataTransfer.SetTables(Database::"Sample Table", Database::"Sample Table");
  SampleDataTransfer.AddConstantValue(true, SampleTable.FieldNo("New Enabled Field"));
  SampleDataTransfer.CopyFields();
end;
```

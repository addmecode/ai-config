# Object Templates

Use these as minimal starting points. Replace IDs, names, and fields for the feature.

## Table

```al
table 50100 "Sample Entity"
{
  DataClassification = CustomerContent;

  fields
  {
    field(1; "No."; Code[20])
    {
      DataClassification = CustomerContent;
    }
  }

  keys
  {
    key(PK; "No.")
    {
      Clustered = true;
    }
  }
}
```

## Page (List)

```al
page 50101 "Sample Entities"
{
  PageType = List;
  ApplicationArea = All;
  SourceTable = "Sample Entity";
  UsageCategory = Lists;

  layout
  {
    area(Content)
    {
      repeater(General)
      {
        field("No."; Rec."No.")
        {
          ApplicationArea = All;
        }
      }
    }
  }
}
```

## Codeunit

```al
codeunit 50102 "Sample Entity Mgt"
{
  procedure ProcessEntity(var SampleEntity: Record "Sample Entity")
  begin
    ValidateEntity(SampleEntity);
    OnAfterProcessEntity(SampleEntity);
  end;

  local procedure ValidateEntity(var SampleEntity: Record "Sample Entity")
  begin
    if SampleEntity."No." = '' then
      Error(EntityNoEmptyErr);
  end;

  [IntegrationEvent(false, false)]
  local procedure OnAfterProcessEntity(var SampleEntity: Record "Sample Entity")
  begin
  end;

  var
    EntityNoEmptyErr: Label 'Entity number cannot be empty.';
}
```

## Enum

```al
enum 50103 "Sample Status"
{
  Extensible = true;

  value(0; Open)
  {
    Caption = 'Open';
  }

  value(1; Closed)
  {
    Caption = 'Closed';
  }
}
```

## Interface

```al
interface ISampleHandler
{
  procedure Handle(var SampleEntity: Record "Sample Entity");
}
```

## Table Extension

```al
tableextension 50104 "Customer Ext Sample" extends Customer
{
  fields
  {
    field(50100; "Sample Enabled"; Boolean)
    {
      DataClassification = CustomerContent;
      Caption = 'Sample Enabled';
    }
  }
}
```

## Page Extension

```al
pageextension 50105 "Customer Card Sample" extends "Customer Card"
{
  layout
  {
    addlast(General)
    {
      field("Sample Enabled"; Rec."Sample Enabled")
      {
        ApplicationArea = All;
      }
    }
  }
}
```

## Upgrade Codeunit

```al
codeunit 50106 "Sample Upgrade"
{
  Subtype = Upgrade;

  trigger OnUpgradePerCompany()
  begin
    UpgradeSampleData();
  end;

  trigger OnUpgradePerDatabase()
  begin
  end;

  local procedure UpgradeSampleData()
  begin
    // Guard with upgrade tags and keep reads protected.
  end;
}
```

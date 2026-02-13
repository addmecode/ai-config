# Performance Patterns

## Pattern: Filter Before Find

Bad:

```al
if Customer.FindSet() then
  repeat
    if Customer.City = CityFilter then
      Count += 1;
  until Customer.Next() = 0;
```

Better:

```al
Customer.SetRange(City, CityFilter);
if Customer.FindSet() then
  repeat
    Count += 1;
  until Customer.Next() = 0;
```

## Pattern: SetLoadFields Early

```al
Item.SetRange(Blocked, false);
Item.SetLoadFields("No.", Description);
if Item.FindSet() then
  repeat
    // Use only loaded fields.
  until Item.Next() = 0;
```

## Pattern: CalcSums Instead of Manual Total

Bad:

```al
if CustLedgerEntry.FindSet() then
  repeat
    TotalAmount += CustLedgerEntry.Amount;
  until CustLedgerEntry.Next() = 0;
```

Better:

```al
CustLedgerEntry.CalcSums(Amount);
TotalAmount := CustLedgerEntry.Amount;
```

## Pattern: Dictionary for Lookup Caching

```al
if Item.FindSet() then
  repeat
    ItemNameByNo.Add(Item."No.", Item.Description);
  until Item.Next() = 0;
```

Use cache lookups instead of repeated `Get` calls in inner loops.

## Pattern: DataTransfer for High-Volume Backfill

```al
MyDataTransfer.SetTables(Database::"My Table", Database::"My Table");
MyDataTransfer.AddSourceFilter(MyTable.FieldNo("New Field"), '=%1', 0);
MyDataTransfer.AddConstantValue(1, MyTable.FieldNo("New Field"));
MyDataTransfer.CopyFields();
```

Use this in upgrade code for large backfills where trigger behavior is acceptable.

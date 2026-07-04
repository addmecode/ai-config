# Test Templates

Use these as starting points and replace IDs, names, and object references.

## Basic Test Codeunit

```al
codeunit 50200 "Sample Feature Tests"
{
  Subtype = Test;

  var
    Assert: Codeunit Assert;

  [Test]
  procedure GivenValidInput_WhenProcessing_ThenExpectedResult()
  var
    SampleResult: Integer;
  begin
    // Given
    SampleResult := 2;

    // When
    SampleResult := SampleResult + 3;

    // Then
    Assert.AreEqual(5, SampleResult, 'Result should be 5.');
  end;
}
```

## Test with Standard Libraries

```al
codeunit 50201 "Sales Posting Tests"
{
  Subtype = Test;

  var
    Assert: Codeunit Assert;
    LibrarySales: Codeunit "Library - Sales";
    LibraryInventory: Codeunit "Library - Inventory";

  [Test]
  procedure GivenSalesOrder_WhenPosting_ThenInvoiceIsCreated()
  var
    SalesHeader: Record "Sales Header";
    SalesLine: Record "Sales Line";
    Item: Record Item;
    PostedInvoiceNo: Code[20];
  begin
    // Given
    LibraryInventory.CreateItem(Item);
    LibrarySales.CreateSalesHeader(SalesHeader, SalesHeader."Document Type"::Order, '');
    LibrarySales.CreateSalesLine(SalesLine, SalesHeader, SalesLine.Type::Item, Item."No.", 1);

    // When
    PostedInvoiceNo := LibrarySales.PostSalesDocument(SalesHeader, true, true);

    // Then
    Assert.AreNotEqual('', PostedInvoiceNo, 'Posted invoice should be created.');
  end;
}
```

## Negative Validation Test

```al
codeunit 50202 "Validation Tests"
{
  Subtype = Test;

  var
    Assert: Codeunit Assert;

  [Test]
  procedure GivenInvalidValue_WhenValidating_ThenErrorIsRaised()
  var
    IsSuccess: Boolean;
  begin
    // Given
    IsSuccess := false;

    // When
    // Call validation that should fail and capture behavior.

    // Then
    Assert.IsFalse(IsSuccess, 'Validation should fail for invalid value.');
  end;
}
```

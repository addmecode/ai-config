# Integration Patterns

Use these snippets as starter shapes.

## Transport Interface

```al
interface IHttpTransportHandler
{
  procedure Send(Request: HttpRequestMessage; var Response: HttpResponseMessage);
}
```

## Request Mapping Interface

```al
interface IIntegrationMessageHandler
{
  procedure BuildRequest(var Request: HttpRequestMessage);
  procedure HandleResponse(Response: HttpResponseMessage);
}
```

## HTTP Request Construction

```al
local procedure BuildJsonPostRequest(Endpoint: Text; Payload: JsonObject; var Request: HttpRequestMessage)
var
  Content: HttpContent;
  PayloadText: Text;
begin
  Payload.WriteTo(PayloadText);
  Content.WriteFrom(PayloadText);
  Content.GetHeaders().Add('Content-Type', 'application/json');

  Request.SetRequestUri(Endpoint);
  Request.Method('POST');
  Request.Content := Content;
  Request.GetHeaders().Add('Accept', 'application/json');
end;
```

## HTTP Send and Validation

```al
local procedure SendAndValidate(Client: HttpClient; Request: HttpRequestMessage; var Response: HttpResponseMessage)
var
  ResponseBody: Text;
  HttpFailureErr: Label 'HTTP request failed with status %1. Response: %2', Comment = '%1 = HTTP status code, %2 = Response body';
begin
  if not Client.Send(Request, Response) then
    Error('Transport error while sending HTTP request.');

  if Response.IsSuccessStatusCode then
    exit;

  Response.Content.ReadAs(ResponseBody);
  Error(HttpFailureErr, Format(Response.HttpStatusCode), ResponseBody);
end;
```

## Bearer Token Header

```al
local procedure AddBearerAuth(var Request: HttpRequestMessage; AccessToken: SecretText)
var
  TokenText: Text;
begin
  TokenText := Format(AccessToken);
  Request.GetHeaders().Add('Authorization', StrSubstNo('Bearer %1', TokenText));
end;
```

## OData Pagination Loop

```al
local procedure ReadAllODataPages(Client: HttpClient; FirstUrl: Text)
var
  Url: Text;
  Request: HttpRequestMessage;
  Response: HttpResponseMessage;
  JsonRoot: JsonObject;
  NextLink: Text;
begin
  Url := FirstUrl;
  while Url <> '' do begin
    Clear(Request);
    Request.SetRequestUri(Url);
    Request.Method('GET');
    Request.GetHeaders().Add('Accept', 'application/json');

    SendAndValidate(Client, Request, Response);
    JsonRoot := ParseAsJsonObject(Response);
    ProcessODataValues(JsonRoot);

    if not TryReadNextLink(JsonRoot, NextLink) then
      NextLink := '';
    Url := NextLink;
  end;
end;
```

## Retry Decision Pattern

```al
local procedure IsTransientStatusCode(StatusCode: Integer): Boolean
begin
  exit(StatusCode in [408, 429, 500, 502, 503, 504]);
end;
```

## API Page Contract Skeleton

```al
page 70200 "My Entity API"
{
  PageType = API;
  APIPublisher = 'mycompany';
  APIGroup = 'integration';
  APIVersion = 'v1.0';
  EntityName = 'entity';
  EntitySetName = 'entities';
  SourceTable = "My Entity";

  layout
  {
    area(content)
    {
      repeater(GroupName)
      {
        field(id; Rec.SystemId) { }
        field(code; Rec."No.") { }
        field(description; Rec.Description) { }
      }
    }
  }
}
```
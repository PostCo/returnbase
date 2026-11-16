# QuickPost API reference

QuickPost is a plain label carrier. It creates labels and reports parcel events by webhook.

Base URL: `http://vendors:4100/quickpost` inside Docker Compose, `http://localhost:4100/quickpost` from your machine. All bodies are JSON.

## Authentication

Send `Authorization: Bearer <key>`. The sandbox accepts any non-empty key. Without one the API answers `401`.

## Errors

Errors use the shape `{ "error": { "code", "message" } }`.

| Status | Code | Meaning |
| --- | --- | --- |
| 400 | invalid_json | The body is not a JSON object |
| 401 | unauthorized | Missing bearer token |
| 404 | not_found | Unknown tracking number |
| 422 | validation_failed | A required field is missing |
| 503 | temporary_failure | QuickPost is temporarily unavailable, `Retry-After: 30` |

## POST /labels

Creates a label. The call is synchronous.

| Field | Type | Notes |
| --- | --- | --- |
| reference | string | Your own number. Required |
| to.name | string | Required |

```json
{ "id": "qpl_1", "reference": "RET-1", "tracking_number": "QP00000001", "status": "label_created",
  "label_url": "http://localhost:4100/quickpost/labels/QP00000001", "created_at": "2026-11-11T09:00:00Z" }
```

`label_url` opens the printable label and needs no key. QuickPost does not deduplicate.

## GET /tracking/:number

```json
{ "tracking_number": "QP00000001", "status": "delivered",
  "events": [ { "status": "label_created", "at": "..." }, { "status": "picked_up", "at": "..." }, { "status": "delivered", "at": "..." } ] }
```

`status` moves from `label_created` to `picked_up` to `delivered`.

## Webhook

QuickPost calls the merchant's webhook URL when a parcel is picked up and when it is delivered. Inside Docker Compose it posts to `http://api:3100/webhooks/quickpost`.

```http
POST /webhooks/quickpost
Content-Type: application/json
X-QuickPost-Event: parcel.picked_up

{ "event": "parcel.picked_up", "tracking_number": "QP00000001", "reference": "RET-1",
  "status": "picked_up", "occurred_at": "2026-11-11T12:00:00Z" }
```

`event` is `parcel.picked_up` or `parcel.delivered`. Each event is sent once, and requests are not signed. Answer with any `2xx` status. QuickPost does not retry a failed delivery, so use `GET /tracking/:number` to catch up.

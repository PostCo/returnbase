# ParcelDock API reference

ParcelDock is a combined label provider. It creates a shipping label and tracking number in one call from its single facility, `PD-01`.

Base URL: `http://vendors:4100/parceldock` inside Docker Compose, `http://localhost:4100/parceldock` from your machine. All bodies are JSON.

## Authentication

Send your key in the `X-Api-Key` header. The sandbox accepts any non-empty key. Without one the API answers `401`.

## Errors

Errors use the shape `{ "error": { "code", "message" } }`.

| Status | Code | Meaning |
| --- | --- | --- |
| 400 | invalid_json | The body is not a JSON object |
| 401 | unauthorized | Missing key |
| 404 | not_found | Unknown tracking number |
| 422 | validation_failed | A required field is missing |
| 503 | temporary_failure | ParcelDock is temporarily unavailable, `Retry-After: 30` |

## POST /shipments

Creates a shipment and its label. The call is synchronous.

| Field | Type | Notes |
| --- | --- | --- |
| reference | string | Your own number. Required |
| recipient.name | string | Required |

```json
{ "id": "pds_1", "reference": "RET-1", "tracking_number": "PD00000001", "status": "label_created",
  "label_url": "http://localhost:4100/parceldock/labels/PD00000001", "facility": "PD-01",
  "created_at": "2026-11-11T09:00:00Z" }
```

`label_url` opens the printable label and needs no key. ParcelDock does not deduplicate: posting twice creates two shipments.

## GET /tracking/:number

```json
{ "tracking_number": "PD00000001", "status": "picked_up",
  "events": [ { "status": "label_created", "at": "2026-11-11T09:00:00Z" },
              { "status": "picked_up", "at": "2026-11-11T12:00:00Z" } ] }
```

`status` moves from `label_created` to `picked_up` to `delivered`. ParcelDock sends no webhooks, so poll this endpoint.

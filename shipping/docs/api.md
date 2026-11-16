# Shipping label service API

Base URL: `http://shipping:4300` inside Docker Compose, `http://localhost:4300` from your machine. All bodies are JSON. The service has no sign-in.

Labels are created asynchronously. A request is answered at once with `pending`. The label is created at the carrier a moment later, and the result is sent to the `callback_url` you gave. Each request is created once: sending the same reference again creates another label.

## Errors

Errors use the shape `{ "error": { "code", "message" } }`.

| Status | Code | Meaning |
| --- | --- | --- |
| 400 | invalid_json | The body is not a JSON object |
| 404 | not_found | Unknown label request id |
| 422 | unknown_carrier | `carrier` is not one the service supports |
| 422 | validation_failed | A required field is missing |

## POST /labels

Requests a label.

| Field | Type | Notes |
| --- | --- | --- |
| reference | string | Your own number. Required |
| carrier | string | `quickpost` or `parceldock`. Required |
| carrier_api_key | string | The shop's ParcelDock key. Required for `parceldock`, unused for `quickpost` |
| recipient_name | string | Required |
| callback_url | string | Where the result is sent. Required |

Answers `202`:

```json
{ "id": "lbl_1", "status": "pending" }
```

## GET /labels/:id

Returns the request in the same shape as the callback. A pending request has no tracking number, label URL or error yet.

## The callback

When the label is created or has failed, the service sends `POST <callback_url>` with the header `X-Shipping-Token: <shared token>`. The token is the value of `SHIPPING_CALLBACK_TOKEN`. The service sends the callback once and does not retry it.

Created:

```json
{ "id": "lbl_1", "reference": "R1001", "status": "created", "carrier": "quickpost",
  "tracking_number": "QP00000001", "label_url": "http://localhost:4100/quickpost/labels/QP00000001" }
```

Failed:

```json
{ "id": "lbl_1", "reference": "R1001", "status": "failed", "carrier": "quickpost",
  "error": "QuickPost is temporarily unavailable. Retry shortly." }
```

The service does not track the parcel. After the label exists, the carrier talks to the requester directly.

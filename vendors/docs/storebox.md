# StoreBox API reference

StoreBox is a warehouse management system (WMS). Merchants connect their own StoreBox account and send returns to a StoreBox warehouse, where staff receive and inspect them.

Base URL: `http://vendors:4100/storebox` inside Docker Compose, `http://localhost:4100/storebox` from your machine. All bodies are JSON.

## Authentication

Send your API key in the `X-Api-Key` header on every request. The sandbox key is `sb_test_key`. A missing or wrong key returns `401`:

```json
{ "error": { "code": "invalid_credentials", "message": "The API key is missing or invalid." } }
```

## Errors

Errors use the shape `{ "error": { "code", "message", "details" } }`. `details` appears on validation errors.

| Status | Code | Meaning |
| --- | --- | --- |
| 400 | invalid_json | The body is not a JSON object |
| 401 | invalid_credentials | Missing or wrong key |
| 404 | not_found | Unknown return |
| 422 | validation_failed | The return is invalid, `details` lists the problems |
| 503 | temporary_failure | StoreBox is temporarily unavailable. The response has `Retry-After: 30`. Nothing was created |

## GET /account

Checks the credentials and returns the account.

```json
{ "account": { "id": "acct_demo", "name": "Demo Merchant", "plan": "standard" } }
```

## GET /warehouses

Lists the warehouses a merchant can send returns to.

```json
{ "warehouses": [ { "id": "wh_rtm", "name": "Rotterdam Main", "country": "NL" } ] }
```

The sandbox has `wh_rtm`, `wh_lds` and `wh_dub`.

## POST /returns

Creates a return at a warehouse. The call is synchronous and answers `201` with the stored return. StoreBox does not support idempotency keys. Sending the same payload twice creates two returns, so check for a stored id before you retry after a timeout.

| Field | Type | Notes |
| --- | --- | --- |
| reference | string | Your own return number. Required |
| warehouse_id | string | An id from `GET /warehouses`. Required |
| items | array | At least one. Required |
| items[].sku | string | Required |
| items[].quantity | integer | 1 or more. Required |
| items[].reason | string | Optional |

```json
{ "id": "sbr_1", "reference": "RET-1", "warehouse_id": "wh_rtm", "status": "pending",
  "items": [ { "sku": "JACKET-M", "quantity": 1, "reason": "too small", "result": null } ],
  "created_at": "2026-11-11T09:00:00Z", "received_at": null, "inspected_at": null }
```

## GET /returns/:id

Returns the same object. StoreBox sends no webhooks, so poll this endpoint for changes.

| status | Meaning |
| --- | --- |
| pending | The warehouse expects the parcel |
| received | The parcel arrived. `received_at` is set |
| inspected | Staff graded every item. `inspected_at` is set and each item has a `result` |

An item `result` is one of `restock` (sellable again), `damaged` or `wrong_item`.

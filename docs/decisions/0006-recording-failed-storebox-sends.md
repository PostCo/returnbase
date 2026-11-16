# 6. Recording failed StoreBox sends

Date: 2026-08-18

## Status

Accepted

## Context

A StoreBox create that failed, whether a 503, a timeout or a rejected payload, left nothing behind. `StoreBox::SendJob` ran once, the error went to the log, and the return looked like any other approved return. Merchants found out when the parcel reached a warehouse that was not expecting it, or when a shopper asked where their refund was.

`store_box_returns` needs StoreBox's id, which only exists once StoreBox has answered, so a failure cannot be kept on that table.

## Decision

`StoreBox::SendService` records every failed create as a `StoreBox::SendAttempt` with the error message, plus a `warehouse_send_failed` timeline event. A return with attempts and no `StoreBox::Return` counts as "send failed" (`ReturnOrder#store_box_status`).

The merchant sees it in three places: a StoreBox panel on the return with the last error and a Retry send button, the "StoreBox send failed" filter in Manage Returns, and the StoreBox status column of the CSV export. Retry runs the same `SendService`, and works only while StoreBox is active.

Nothing retries on its own.

## Consequences

- A failed send stays visible until someone deals with it.
- A StoreBox outage means retrying each affected return by hand.
- Every attempt is kept, so the return shows how many failed before one got through.
- Sends that Returnbase refuses before calling StoreBox (StoreBox not active, the location not mapped) are not attempts and leave no record.
- StoreBox's create takes no idempotency key. If StoreBox creates the return but the response is lost on the way back, Returnbase records a failed attempt, and Retry creates a second return at StoreBox for the same reference.

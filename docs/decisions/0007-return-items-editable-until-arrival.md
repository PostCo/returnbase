# 7. Return items can be edited until the parcel arrives

Date: 2026-09-29

## Status

Accepted

## Context

Shoppers write in after they submit: they picked the wrong size to exchange for, they put a second item in the parcel, or they want a refund instead of an exchange. Support used to reject the return and ask the shopper to start again, which threw away the label, the reservation and the shopper's patience.

## Decision

The merchant can edit a return's items (add, remove, change the quantity, reason or resolution) while it is submitted, approved or in transit (`ReturnOrder#editable?`). Editing stops once the return is received.

`ReturnOrders::UpdateItemsService` replaces the items in one transaction. For an approved return it runs `ReserveExchangesService` again, so the held stock matches the new exchange items. On resolve, `RefundService` pays what the refund items now total minus anything already refunded, so an edit after a pickup refund is settled then.

## Consequences

- Warehouses are not told. A return already at StoreBox keeps the items it was sent with, and StoreBox grades what it was told to expect.
- An edit that lowers the refund after a pickup refund is not clawed back. `RefundService` only ever pays a positive difference.
- The label and tracking number stay the same.
- An edit is recorded on the timeline (`items_edited`).

# 10. Items are accepted or rejected one by one at resolve

Date: 2026-11-16

## Status

Accepted

## Context

A received parcel is often only partly good. One item is damaged or is not what the shopper said it was, and the other two are fine. Resolve used to be one decision for the whole return: refund every refund item, ship every exchange, and put everything back in stock (or nothing). A merchant who wanted to refuse one item had to refuse all of them or fix the money and the stock by hand afterwards.

## Decision

When the merchant resolves a received return, they decide each item. An item is accepted or rejected (`ReturnItem#outcome`, empty until decided). For an accepted item they also choose whether it goes back in stock (`ReturnItem#restock`). A rejected item is never restocked.

`ReturnOrders::ResolveService` takes the decisions, which must cover each item once, saves them in one transaction and records an `items_decided` timeline event. Then:

- With at least one accepted item, the return is resolved. `RefundService` pays the refund items that are not rejected, `RestockService` restocks the accepted items marked for it, and `FulfilExchangesService` ships the exchanges whose item was accepted and destroys, which releases, the exchanges whose item was rejected (`Exchange#return_item_id`).
- With every item rejected, the return ends `rejected` and every exchange hold is released. `reject` runs from received as well as submitted. Reject on a received return is the same as rejecting every item. The shopper is emailed whenever a return becomes rejected.

Without decisions, every item is accepted with its default restock choice. StoreBox's automatic resolve works this way, so a graded return is still resolved without the merchant.

The default restock choice, `ReturnItem#restock_default`, comes from the shop's setting and the item's grade ([decision 0009](0009-restock-on-resolve.md)).

`RefundService` totals refund items whose outcome is not rejected, so a return refunded at carrier pickup, before any decision, counts every item. The refund is not taken back if the merchant later rejects an item. `RefundService` only ever pays a positive difference ([decision 0003](0003-refund-on-carrier-pickup.md)).

## Who it serves

The merchant who inspects returns by hand, or who sees a warehouse's grades, and wants the refund, the stock and the replacement stock to follow what they decided for each item. The shopper sees each item's outcome on the status page and in the emails.

## Option dropped

One decision for the whole return, with the refund and the stock left for the merchant to correct by hand. It cannot express "accept two items and reject the third", which is the common case.

## Consequences

- A return can end rejected after it was received. Its status page shows the items as not accepted.
- A pickup refund for an item that is later rejected stays paid. Getting the money back happens outside Returnbase.
- StoreBox grades still become the item's condition. They set the default tickbox, and the merchant's choice wins when the merchant resolves by hand.
- Resolved returns made before this change have no outcome on their items.

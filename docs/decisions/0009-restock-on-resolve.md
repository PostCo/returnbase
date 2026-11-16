# 9. Restock on resolve, driven by grades

Date: 2026-11-12

## Status

Accepted. Amended 2026-11-16: the setting is now the default for each item's tickbox ([decision 0010](0010-items-are-decided-one-by-one-at-resolve.md)).

## Context

A resolved return used to leave stock alone. Merchants put the items back by hand, and some forgot. Putting everything back is wrong too: a warehouse that inspects returns grades some items as damaged or not the item that was sent, and those cannot be sold again.

## Decision

Each shop has a setting, `restock_on_resolve`, off by default and switched on the Settings page.

**Amendment, 2026-11-16.** The setting no longer decides whether a return is restocked. It is the default for each item's "Put back in stock" tickbox in the Resolve dialog: `ReturnItem#restock_default` is true when the setting is on and the item is not graded `not_restockable`. The merchant decides per item, and `ReturnOrders::ResolveService` calls `ReturnOrders::RestockService` after the refund. The service adds the quantity of each accepted item marked for restock to `InventoryLevel.available` at the return's location, creating the level when the variant has none there. It records a `restocked` timeline event listing what went back and what was skipped. An automatic resolve, such as StoreBox's, has no dialog and uses the defaults.

The default depends on `ReturnItem#condition`, which is empty until someone inspects the item. `restockable` and `not_restockable` come from the inspector. An item with no condition starts ticked, because nobody said otherwise. An item `not_restockable` starts unticked.

StoreBox sets the condition. Each StoreBox result has a "Back in stock" choice in its result mapping (`StoreBox::ResultMapping#restock`). `StoreBox::PollService` copies it onto the item when StoreBox grades the return. The defaults are restock yes, damaged no, wrong item no.

## Consequences

- Stock changes once, when the return is resolved. Nothing moves at approval, pickup or receipt.
- Exchange items are held and shipped as before. Restocking adds back the items the shopper sent, whichever resolution they chose.
- A return resolved by hand before its items are graded starts with every item ticked. The merchant can see the condition on the return page before pressing Resolve, and can tick or untick any item.
- Turning the setting on later does not restock returns that are already resolved.

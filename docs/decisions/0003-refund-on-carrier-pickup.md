# 3. Refund on carrier pickup

Date: 2026-04-21
Amended: 2026-07-06 (StoreBox warehouses added to the list)

## Status

Accepted

## Context

Merchants with prepaid labels asked to refund as soon as the carrier collects the parcel. A return takes days to reach them, the shopper is out of pocket the whole time, and most of those emails to support are "where is my refund?".

A carrier scan proves the shopper sent a parcel. It says nothing about what is inside. For a shop that inspects its own returns that risk is the merchant's call. For returns that go to a warehouse that inspects them, the inspection is the reason the merchant pays for the warehouse.

## Decision

Each shop has a setting, `refund_on_carrier_pickup`, off by default and switched on the Settings page.

When QuickPost reports `parcel.picked_up`, `Shipments::PickedUpService` moves the return to in transit and calls `ReturnOrders::AfterPickedUpService`. With the setting on, that service refunds the refund items straight away, unless the return's location belongs to a warehouse that inspects returns. Those warehouses are listed by location flag in `inspecting_warehouse_flags` (`app/services/return_orders/after_picked_up_service.rb:20`).

Only prepaid-label returns have carrier events, so own-postage returns are never refunded on pickup.

`ReturnOrders::RefundService` records only what the refund items total beyond refunds already made, so resolving the return later does not pay twice.

**Amendment, 2026-07-06.** StoreBox shipped, and `store_box_warehouse` was added to the list.

## Consequences

- The list is kept by hand.
- A return refunded at pickup that turns out to be damaged is already paid. Getting the money back happens outside Returnbase.
- The check reads the location's flag, not whether the integration is active. Locations stay flagged after StoreBox is deactivated, so their returns are still not refunded on pickup.
- Kopi Threads has the setting on in the seeds.

# StoreBox Return Flow

## Overview

StoreBox is a warehouse management system (WMS). Returnbase stays the shopper's returns portal: it approves the return and, for a prepaid-label return, asks the shipping service for the label ([label_return.md](label_return.md)). A return whose location the merchant mapped to a StoreBox warehouse is sent to StoreBox once it is approved. StoreBox receives the parcel, grades each item, and Returnbase reads that back by polling and acts on it.

The flow has two halves:

1. **Outbound.** After approval, Returnbase creates the return at StoreBox (`POST /returns`) from a background job. A failure is recorded and can be retried.
2. **Inbound.** Every minute, Returnbase reads each open StoreBox return (`GET /returns/:id`). Received means the return is received. Inspected means the merchant's result mapping decides between resolving it now and leaving it for review.

StoreBox's API reference is [vendors/docs/storebox.md](../../vendors/docs/storebox.md).

## Prerequisites (setup)

The merchant sets StoreBox up on Integrations, then StoreBox (`web/src/pages/integrations/StoreBoxSettings.tsx`).

- **Connect.** `StoreBoxIntegration::CreateForm` checks the API key with `GET /account` and creates the integration as `connected`.
- **Locations.** Each return location can send to one StoreBox warehouse (`StoreBox::LocationMapping`). Saving a mapping also sets the location's `store_box_warehouse` flag (`app/models/location.rb:10`). Locations left as "Not sent to StoreBox" are never sent.
- **Inspection results.** Each StoreBox result (`restock`, `damaged`, `wrong_item`) maps to an action, `resolve` or `manual_review` (`StoreBox::ResultMapping`).
- **Activate.** `StoreBoxIntegration::ReadinessService` lists what is missing. Only `ActivateForm` sets `active`, and saving never does. See [decision 0005](../decisions/0005-storebox-activation-is-a-merchant-decision.md).

## Outbound: handing the return to StoreBox

A return reaches the warehouse code from two places, depending on how the shopper sends it.

```
Merchant presses Approve                          (POST /api/returns/:id/approve)
  └─ ReturnOrders::ApproveService                  one transaction
       ├─ return_order.approve!                     timeline: status_changed
       ├─ ReturnOrders::ReserveExchangesService     holds stock for exchange items
       └─ ReturnOrders::AfterReviewService
            ├─ own postage ─→ ReturnOrders::SendToWarehouseService          (after_review_service.rb:13)
            └─ label       ─→ Shipments::CreateRemoteOrderService
                                ├─ asks the shipping service for the label (QuickPost, or ParcelDock when enabled)
                                └─ Shipment pending, timeline: label_requested
  └─ ReturnMailer.approved                         after the transaction

Later, when the shipping service calls back        (POST /webhooks/shipping)
  └─ Shipments::LabelCreatedService
       ├─ Shipment label_created, timeline: shipment_created
       ├─ ReturnMailer.label_ready
       └─ ReturnOrders::SendToWarehouseService     (label_created_service.rb:20)

ReturnOrders::SendToWarehouseService
  └─ StoreBox active? and location.store_box_warehouse?
       └─ StoreBox::SendJob.perform_later           (send_to_warehouse_service.rb:7)
```

Things to know:

- **Two entry points, one gate.** Own-postage returns have no label, so nothing happens to them after approval and they are sent straight away. Label returns are sent once the shipping service has called back with the label. Both call `SendToWarehouseService`, which is the only place that decides whether StoreBox gets the return.
- **A label failure leaves the return approved and unsent.** The shipment becomes `label_failed`. The return goes to the warehouse only after the merchant presses "Request label again" and the new label arrives.
- **Activation sends nothing by itself.** A return goes to StoreBox only when it reaches one of the two entry points while StoreBox is active.

```
StoreBox::SendJob                                 (worker)
  └─ StoreBox::SendService
       ├─ already has a StoreBox::Return           → refused, nothing recorded
       ├─ StoreBox not active                      → refused, nothing recorded
       ├─ location has no warehouse mapping        → refused, nothing recorded
       ├─ POST /storebox/returns {reference, warehouse_id, items: [{sku, quantity, reason}]}
       ├─ 201 → StoreBox::Return pending with StoreBox's id, timeline: sent_to_warehouse
       └─ any VendorClient::Error
            → StoreBox::SendAttempt with the error, timeline: warehouse_send_failed
```

The job runs once. A failure is not retried on its own. See [decision 0006](../decisions/0006-recording-failed-storebox-sends.md).

### Failed sends and Retry

A return with a `StoreBox::SendAttempt` and no `StoreBox::Return` is "send failed" (`ReturnOrder#store_box_status`). The merchant sees it:

- on the return, as a StoreBox panel with the last error and a **Retry send** button (`web/src/pages/integrations/StoreBoxReturnPanel.tsx`),
- in Manage Returns, under the **StoreBox send failed** filter (`ReturnOrder.store_box_send_failed`),
- in the CSV export's StoreBox status column.

Retry calls `POST /api/returns/:id/send_to_store_box`, which runs the same `StoreBox::SendService`. It is offered only while StoreBox is active.

## Inbound: polling

```
StoreBox::PollJob                                 every minute (config/recurring.yml)
  └─ each active StoreBoxIntegration
       └─ each open StoreBox::Return (pending, received)
            └─ StoreBox::PollService: GET /storebox/returns/:remote_id      one transaction
                 ├─ StoreBox says received or inspected, and ours is pending
                 │    └─ StoreBox::Return received, ReturnOrders::ReceiveService (if can_receive?)
                 └─ StoreBox says inspected
                      ├─ action = StoreBoxIntegration#action_for(results)
                      ├─ each item's condition set from its result's restock choice (restockable or not_restockable)
                      ├─ StoreBox::Return inspected with results and action, timeline: warehouse_inspected
                      └─ action resolve → ReturnOrders::ResolveService with no decisions: every item accepted with its default restock choice (refund, restock, ship exchanges, emails)
                         action manual_review → the return stays received for the merchant
```

**One action per return.** Each item's result maps to an action, and the most cautious one wins: one item whose result is mapped to manual_review leaves the whole return for review (with Kopi Threads’ seeded mapping, a damaged item does) (`StoreBox::ResultMapping::ACTIONS`, least cautious first). A result with no mapping counts as `manual_review`.

**Restocking.** An item graded with a result whose restock choice is off gets the condition `not_restockable`, which makes its default restock choice off. The automatic resolve accepts every item with the defaults, so `ReturnOrders::RestockService` leaves that item out. When the merchant resolves by hand, the Resolve dialog starts each tickbox at the same default and the merchant can change it, or reject the item. A result with no mapping counts as not restockable. See [decision 0009](../decisions/0009-restock-on-resolve.md) and [decision 0010](../decisions/0010-items-are-decided-one-by-one-at-resolve.md).

A failed read is logged as a warning and tried again next minute. See [decision 0004](../decisions/0004-polling-storebox.md).

## The pickup refund check

Label returns going to StoreBox still travel with QuickPost, and QuickPost's `parcel.picked_up` webhook reaches them like any other:

```
POST /webhooks/quickpost {event: "parcel.picked_up"}
  └─ Shipments::PickedUpService                    shipment picked_up, return in_transit
       └─ ReturnOrders::AfterPickedUpService
            ├─ shop.refund_on_carrier_pickup? off → nothing
            ├─ location flag in inspecting_warehouse_flags → nothing   (after_picked_up_service.rb:20)
            └─ otherwise → ReturnOrders::RefundService (refunded before the parcel arrives)
```

`store_box_warehouse` is on that list, so a StoreBox return is refunded after StoreBox inspects it and never at pickup. Kopi Threads has refund on pickup switched on, so this check is what protects its StoreBox returns. See [decision 0003](../decisions/0003-refund-on-carrier-pickup.md).

## Deactivation with returns in flight

`DeactivateForm` sets `disabled`. From then on:

- `SendToWarehouseService` sends nothing new, and Retry is not offered.
- `PollJob` skips the integration, so returns already at StoreBox stop moving even if StoreBox grades them.
- Each sent return keeps its `StoreBox::Return`. Its panel says StoreBox is no longer checked, and the merchant receives and resolves it by hand.
- Locations keep their `store_box_warehouse` flag and mapping, so Activate picks up where it left off.

## What the merchant sees

| Where | What |
| --- | --- |
| Integrations, StoreBox card | Not connected, Connected not active, Active or Deactivated |
| StoreBox settings | The checklist, mappings, the key hint, Activate or Deactivate |
| Return page, StoreBox panel | Send failed with Retry, Expected at StoreBox, Received by StoreBox, or Inspected with each item's result and the action taken |
| Return timeline | Sent to StoreBox, Could not send to StoreBox, StoreBox inspected the items |
| Manage Returns | The StoreBox send failed filter, and the StoreBox status column in the export |

## Worked example

Kopi Threads has StoreBox active, with Kuala Lumpur Returns Hub mapped to `wh_rtm` and `restock` mapped to `resolve`.

1. A shopper returns a tee for a refund and chooses to post it themselves. The return is at Kuala Lumpur Returns Hub.
2. The merchant approves it. `AfterReviewService` sends it straight to `SendToWarehouseService`, which queues `StoreBox::SendJob`.
3. The job posts to StoreBox. The StoreBox request log shows `POST /storebox/returns` with `warehouse_id: wh_rtm`, and the return's panel shows Expected at StoreBox.
4. In the StoreBox console, mark it received. Within a minute the return is received.
5. In the console, record `restock` for the item. Within a minute the return is resolved, the refund is recorded, and Mailpit has the refund email.

Switch StoreBox's scenario to `temporary_failure` before step 2 to see a failed send, then back to `normal` and press Retry send.

## Key files

| File | Role |
| --- | --- |
| `app/models/store_box_integration.rb` | The integration, its statuses and `action_for` |
| `app/models/store_box/` | Location and result mappings, `Return`, `SendAttempt` |
| `app/forms/store_box_integration/` | Create, update, credentials, activate, deactivate |
| `app/services/store_box_integration/readiness_service.rb` | What setup still needs |
| `app/services/return_orders/after_review_service.rb` | Entry point for own-postage returns |
| `app/services/shipments/create_remote_order_service.rb`, `label_created_service.rb` | Request the label, and hand the return on when it arrives |
| `app/services/return_orders/send_to_warehouse_service.rb` | Decides whether StoreBox gets the return |
| `app/services/store_box/send_service.rb`, `app/jobs/store_box/send_job.rb` | The create call and failed attempts |
| `app/services/store_box/poll_service.rb`, `app/jobs/store_box/poll_job.rb` | Reading StoreBox back |
| `app/services/return_orders/after_picked_up_service.rb` | The pickup refund check |
| `app/clients/store_box_client.rb` | The HTTP client |
| `test/services/store_box_test.rb`, `e2e/tests/03-storebox.spec.ts` | Tests |

## Decision records

- [0001 Solid Queue on Postgres](../decisions/0001-solid-queue-on-postgres.md)
- [0003 Refund on carrier pickup](../decisions/0003-refund-on-carrier-pickup.md)
- [0004 Polling StoreBox](../decisions/0004-polling-storebox.md)
- [0005 StoreBox activation is the merchant's decision](../decisions/0005-storebox-activation-is-a-merchant-decision.md)
- [0006 Recording failed StoreBox sends](../decisions/0006-recording-failed-storebox-sends.md)
- [0007 Return items can be edited until the parcel arrives](../decisions/0007-return-items-editable-until-arrival.md)
- [0008 Labels come from the shipping service](../decisions/0008-labels-come-from-the-shipping-service.md)
- [0009 Restock on resolve, driven by grades](../decisions/0009-restock-on-resolve.md)
- [0010 Items are accepted or rejected one by one at resolve](../decisions/0010-items-are-decided-one-by-one-at-resolve.md)

# 8. Labels come from the shipping service

Date: 2026-11-12

## Status

Accepted

## Context

Returnbase used to buy a label itself while the merchant's Approve request waited. `Shipments::CreateRemoteOrderService` called QuickPost, or ParcelDock for shops that had it, and a failed call rolled the approval back. The shipping team now runs one label service for every team's systems, with the carrier accounts and keys behind it. Two things follow. Creating a label takes a moment and can fail after the request was accepted. And the other teams' systems should not each hold a copy of the carrier calls.

## Decision

Returnbase asks the shipping service for a label and finishes the work when the service calls back.

- `CreateRemoteOrderService` sends `POST /labels` (`ShippingClient`), creates the shipment as `pending` with the service's request id, and records `label_requested` on the timeline. It no longer talks to a carrier and no longer hands the return to a warehouse.
- The service creates the label at the carrier and calls `POST /webhooks/shipping` with a shared token. `Shipments::LabelCreatedService` stores the tracking number and label URL, moves the return to the ParcelDock facility when ParcelDock sold the label, emails the label to the shopper, and then calls `ReturnOrders::SendToWarehouseService`. `Shipments::LabelFailedService` stores the error.
- A label return therefore reaches a warehouse only when its label callback arrives. Own-postage returns have no label and are still handed over at approval.
- If the request itself fails, or the service reports a failed label, the shipment is `label_failed` and the approval stays. The merchant presses "Request label again" (`POST /api/returns/:id/request_label`) on the return. Nothing retries on its own.
- Carrier tracking is unchanged. QuickPost still sends pickup and delivery webhooks straight to Returnbase.

The shipping service is the shipping team's. Returnbase engineers do not change `shipping/`. A change goes through that team.

## Consequences

- Approving a label return no longer fails when the carrier is down. The merchant sees a failed label on the return and requests it again.
- Between approval and the callback a label return is approved but has no label, no tracking number and has not been sent to any warehouse. The status page tells the shopper the label is on its way.
- The callback is sent once. A callback that never arrives leaves the shipment pending, and nothing in Returnbase notices.
- `ParcelDockClient` and `QuickPostClient` are no longer used by the label path. The carrier choice is now a field of the request.

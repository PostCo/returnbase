# ParcelDock Return Flow

## Overview

ParcelDock sells prepaid return labels, and its one facility, PD-01, receives the parcels. When a shop has ParcelDock enabled, every prepaid-label return gets its label from ParcelDock in place of QuickPost and is pointed at the facility location once its first label arrives, unless the merchant has moved it. Own-postage returns never touch ParcelDock.

Returnbase does not call ParcelDock itself. It asks the shipping team's label service for a ParcelDock label at approval, and the service calls back with the result ([label_return.md](label_return.md)). ParcelDock sends nothing to Returnbase.

ParcelDock's API reference is [vendors/docs/parceldock.md](../../vendors/docs/parceldock.md).

## Prerequisites (setup by support)

Merchants cannot set ParcelDock up themselves. Their Integrations page shows a ParcelDock card that tells them support manages it. See [decision 0002](../decisions/0002-parceldock-is-set-up-by-support.md) for why.

Support uses `/admin/parcel_dock` (`Admin::ParcelDockController`, HTTP basic auth, user `admin`):

- **API key.** Saved as typed, with no check against ParcelDock. Leaving it blank keeps the current key.
- **Facility location.** One of the shop's locations gets the `parcel_dock_facility` flag (`app/models/location.rb:10`), and every other location loses it. Lumen Home's seeded facility is "ParcelDock PD-01".
- **Enabled.** `ParcelDockIntegration` is `enabled` or `disabled`. There is no readiness check or activation step.

## Handing the return to ParcelDock

```
Merchant presses Approve on a label return
  └─ ReturnOrders::ApproveService                  one transaction
       └─ ReturnOrders::AfterReviewService
            └─ Shipments::CreateRemoteOrderService
                 ├─ ShippingClient POST /labels {carrier: "parceldock" when enabled, otherwise "quickpost", carrier_api_key, ...}
                 └─ Shipment pending, timeline: label_requested

The shipping service calls back          (POST /webhooks/shipping)
  └─ Shipments::LabelCreatedService
       ├─ return_order.location = the facility          (label_created_service.rb:13)
       ├─ Shipment label_created with ParcelDock's tracking number and label URL
       ├─ ReturnMailer.label_ready
       └─ ReturnOrders::SendToWarehouseService          (label_created_service.rb:20)
            └─ StoreBox only, and only if the facility is a StoreBox warehouse
```

The label request is the hand-off: creating the shipment at ParcelDock is how ParcelDock learns the parcel is coming. The shopper gets the label link by email and on the status page once the label arrives, and the merchant sees it on the return.

Own-postage returns follow the other entry point (`AfterReviewService` straight to `SendToWarehouseService`) and stay at the location they were submitted to.

### When the label fails

Any ParcelDock error (the sandbox’s temporary_failure scenario shows one) reaches Returnbase as a failed label callback. The approval stands, the shipment is `label_failed` with the error, the return stays at its own location, and the merchant presses "Request label again" once ParcelDock answers.

## After the label

ParcelDock sends no webhooks. Its sandbox console can mark a parcel picked up or delivered, but nothing reaches Returnbase, so a ParcelDock return stays approved until the merchant marks it received and resolves it.

For the same reason the pickup refund check (`ReturnOrders::AfterPickedUpService`) never runs for ParcelDock labels. The facility's `parcel_dock_facility` flag is not in `inspecting_warehouse_flags` there (`after_picked_up_service.rb:20`). It has not mattered because no pickup event arrives. See [decision 0003](../decisions/0003-refund-on-carrier-pickup.md).

## Switching ParcelDock off

Support unticks Enabled. New label returns get QuickPost labels again and stay at their own location. Returns already pointed at the facility keep that location and their ParcelDock label.

## Key files

| File | Role |
| --- | --- |
| `app/models/parcel_dock_integration.rb` | The integration and `#facility` |
| `app/controllers/admin/parcel_dock_controller.rb`, `app/views/admin/parcel_dock/index.html.erb` | Support's setup page |
| `app/services/shipments/create_remote_order_service.rb` | Picks the carrier for the label request |
| `app/services/shipments/label_created_service.rb` | Moves the return to the facility when its first label arrives, unless the merchant moved it |
| `web/src/pages/integrations/cards.tsx` | The merchant's ParcelDock card |
| `test/services/parcel_dock_test.rb`, `e2e/tests/04-parceldock.spec.ts` | Tests |

# Label Return Flow

## Overview

A prepaid-label return gets its label from the shipping team's label service. Returnbase asks for it when the merchant approves the return, the service creates it at the carrier in the background, and the service calls Returnbase back with the result. Until that callback the return is approved but has no label, and no warehouse has heard of it. See [decision 0008](../decisions/0008-labels-come-from-the-shipping-service.md).

The service's API is in [shipping/docs/api.md](../../shipping/docs/api.md). Returnbase engineers do not change `shipping/`.

## Asking for the label

```
Merchant presses Approve on a label return
  └─ ReturnOrders::ApproveService                  one transaction
       └─ ReturnOrders::AfterReviewService
            └─ Shipments::CreateRemoteOrderService
                 ├─ ShippingClient POST /labels {reference, carrier, carrier_api_key, recipient_name, callback_url}
                 │     carrier is "parceldock" when the shop has ParcelDock enabled, otherwise "quickpost"
                 ├─ Shipment pending with label_request_id, timeline: label_requested
                 └─ nothing is sent to a warehouse
  └─ ReturnMailer.approved                         "your label will follow by email"
```

## The callback

```
POST /webhooks/shipping  (header X-Shipping-Token)       Webhooks::ShippingController
  ├─ status "created" → Shipments::LabelCreatedService
  │     ├─ ParcelDock label → return_order.location = the facility, unless the merchant moved it   (label_created_service.rb:13)
  │     ├─ Shipment label_created with tracking number and label URL, timeline: shipment_created
  │     ├─ return cancelled while the label was made → stops here
  │     ├─ ReturnMailer.label_ready                                    the shopper's label email
  │     └─ ReturnOrders::SendToWarehouseService                        (label_created_service.rb:20)
  └─ status "failed"  → Shipments::LabelFailedService
        └─ Shipment label_failed with the error, timeline: label_failed
```

The controller looks the shipment up by the request id and only accepts a callback for a shipment that is still pending, so a repeated callback is refused.

## When the label fails

If the request cannot be sent (the service is down), `CreateRemoteOrderService` records the failure through `LabelFailedService` and the approval still succeeds. If the service accepts the request and the carrier then refuses it, the callback says `failed`. Both leave the shipment `label_failed` with the error, which the return detail page shows with a "Request label again" button (`POST /api/returns/:id/request_label`, `Shipments::RetryLabelService`). A new request replaces the old one. Nothing retries on its own.

## After the label

Carrier tracking does not go through the shipping service. QuickPost sends `parcel.picked_up` and `parcel.delivered` to `/webhooks/quickpost`, and refund on pickup works as before ([decision 0003](../decisions/0003-refund-on-carrier-pickup.md)). ParcelDock sends nothing.

## Key files

| File | Role |
| --- | --- |
| `app/services/shipments/create_remote_order_service.rb` | Requests the label |
| `app/services/shipments/label_created_service.rb`, `label_failed_service.rb` | Finish the request on callback |
| `app/services/shipments/retry_label_service.rb` | The merchant's "Request label again" |
| `app/controllers/webhooks/shipping_controller.rb` | Receives the callback and checks the token |
| `app/clients/shipping_client.rb` | The HTTP client |
| `shipping/` | The label service, owned by the shipping team |
| `test/services/label_service_test.rb`, `test/integration/shipping_webhook_test.rb`, `e2e/tests/05-shipping-labels.spec.ts` | Tests |

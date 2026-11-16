# Glossary

The words we use in code, in the dashboard and when we talk about returns. Where the code uses a different name, it is in the last column.

| Term | Meaning | In code |
| --- | --- | --- |
| Return | One shopper's request to send items back from one order | `ReturnOrder` |
| Return number | The shop's number for a return, such as R1041. Numbers are per shop | `ReturnOrder#number` |
| Return item | One line of a return: what, how many, why, and refund or exchange | `ReturnItem` |
| Resolution | What the shopper wants for an item: a refund or an exchange | `ReturnItem#resolution` |
| Return location | Where the parcel should go. New returns get the shop's default location | `Location` |
| Default location | The active return location new shopper returns go to. It cannot be archived. A shop with none set uses its first active location | `Shop#default_location`, `Shop#return_location` |
| Archived location | A location retired by the merchant. It is not offered as a default or a move target, and returns already there keep it | `Location#archived_at` |
| Move | The merchant sends a submitted or approved return to another active location | `ReturnOrders::MoveService` |
| Shipping method | How the parcel travels: a prepaid label, or the shopper posts it themselves (own postage) | `ShippingMethod#kind` (`label`, `own_postage`) |
| Prepaid label | A label the shipping service creates for a label return, from QuickPost or ParcelDock | `Shipment#label_url` |
| Label service | The shipping team's service that creates labels for Returnbase and calls back with the result. Returnbase does not change it | `shipping/`, `ShippingClient` |
| Label request | Returnbase's ask for one label. The shipment is pending until the service calls back | `Shipment#label_request_id` |
| Label callback | The service's call to `POST /webhooks/shipping` with the created or failed label. A label return reaches a warehouse only after it | `Webhooks::ShippingController` |
| Label failed | The label could not be requested or created. The merchant requests it again | `Shipment` `label_failed`, `POST /api/returns/:id/request_label` |
| Own postage | The shopper pays postage and gets posting instructions. No label, no tracking | `ReturnOrder#posting_instructions` |
| Shipment | The parcel for a label return, with its tracking number | `Shipment` |
| Carrier | Whoever moves the parcel. QuickPost by default | `QuickPostClient` |
| Pickup | The carrier's first scan of the parcel. Moves the return to in transit | `Shipments::PickedUpService` |
| Refund on carrier pickup | Shop setting: refund label returns at pickup, except at warehouses that inspect | `Shop#refund_on_carrier_pickup` |
| Inspecting warehouse list | The location flags whose returns are never refunded at pickup | `inspecting_warehouse_flags` in `AfterPickedUpService` |
| Cancelled | A return the merchant or the shopper called off while it was submitted or approved. Held exchange stock is released and the shopper is emailed | `cancelled` status, `ReturnOrders::CancelService` |
| Put items back in stock by default | Shop setting: accepted items start ticked to go back in stock when the return is resolved, except items graded not restockable. Automatic resolves use these defaults | `Shop#restock_on_resolve`, `ReturnItem#restock_default` |
| Outcome | The merchant's decision for one item when the return is resolved: accepted or rejected. Empty until then | `ReturnItem#outcome` |
| Restock choice | Whether an accepted item goes back in stock. Always false for a rejected item. Empty until the return is resolved | `ReturnItem#restock` |
| Condition | Whether an inspected item can be sold again: restockable or not restockable. Empty when nobody inspected it | `ReturnItem#condition` |
| Received | The parcel has arrived and nothing has been decided yet | `received` status |
| Resolved | At least one item was accepted. The refund is recorded and the exchanges for accepted items have shipped | `resolved` status |
| Rejected | A submitted return the merchant refused, or a received return whose items were all rejected. The shopper is emailed | `rejected` status, `ReturnOrders::RejectService` |
| Refund | A record of money paid back. Simulated: no payment provider is called | `Refund` |
| Exchange | A replacement variant for a returned item | `Exchange` |
| Reservation | Stock held at the return location for an exchange, from approval until resolve | `Reservation` |
| Timeline | The history on a return's page | `TimelineEvent` |
| Manage Returns | The merchant's list of returns, with filters and CSV export | `web/src/pages/ManageReturns.tsx` |
| Integration | A vendor a shop has connected | `Integration` and its subclasses |
| Connected | StoreBox accepted the key, but nothing is sent yet | `StoreBoxIntegration` `connected` |
| Readiness | Whether StoreBox's setup is complete. Says nothing about whether it is on | `StoreBoxIntegration::ReadinessService` |
| Active, Deactivated | StoreBox switched on or off by the merchant | `active`, `disabled` |
| Warehouse | A StoreBox site that receives parcels, such as `wh_rtm` | `StoreBox::LocationMapping#warehouse_id` |
| Location mapping | Which StoreBox warehouse a return location sends to | `StoreBox::LocationMapping` |
| Inspection result | StoreBox's grade for one item: restock, damaged or wrong item | `StoreBox::ResultMapping::RESULTS` |
| Result mapping, action | What Returnbase does for a result: resolve now, or leave for manual review | `StoreBox::ResultMapping` |
| Result mapping, back in stock | Whether items with a result get the condition restockable or not restockable | `StoreBox::ResultMapping#restock` |
| Send failed | Returnbase tried to send a return to StoreBox and StoreBox did not take it | `StoreBox::SendAttempt` |
| Retry send | The merchant's button to try a failed send again | `POST /api/returns/:id/send_to_store_box` |
| Facility | ParcelDock's one site, PD-01, and the location flagged for it | `parcel_dock_facility` |
| Support | Returnbase staff. They manage ParcelDock from the admin page | `Admin::ParcelDockController` |
| Shopper page, status page | Where shoppers file a return and follow it, at `/shopper` | `web/src/shopper/` |
| Fake vendors | The sandbox QuickPost, StoreBox and ParcelDock in `vendors/` | `vendors/` |
| Shipping console | The label service's page with its requests, scenario switch and log, at port 4300 | `shipping/` |
| Console, request log, scenario | A fake vendor's page to play its side, its record of every call, and its failure switch | `/<vendor>/console`, `/<vendor>/log`, `/<vendor>/admin/scenario` |
| Mailpit | Catches every email Returnbase sends, at port 8125 | `SMTP_HOST` |

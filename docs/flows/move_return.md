# Editing Locations and Moving a Return

## Overview

A merchant edits a return location's name, city and address on the **Locations** page, archives locations it no longer uses, and chooses one active location as the shop's default. New shopper returns go to the default (`Shop#return_location`, which falls back to the first active location). The address is what an own-postage shopper is told to post to, in the approval email and on the status page (`ReturnOrder#posting_instructions`).

An archived location is kept, with the returns that are already there, but it cannot be the default and cannot be chosen as a move target. The default location cannot be archived: make another location the default first. A location is archived or restored by `archived_at`.

## Moving a return

A return can be moved while it is `submitted` or `approved`, before the carrier or the shopper has it. The merchant presses **Move** on the return page and picks an active location. The web app calls `POST /api/returns/:id/move` with `location_id`.

```
ReturnOrders::MoveService(return_order:, location:)               one transaction
  ├─ return_order.location = location             timeline: moved (from, to)
  └─ approved only
       ├─ ReserveExchangesService                  holds the exchange stock at the new location, or fails if it is short
       └─ label return with a shipment
            ├─ clears the old label and tracking number
            └─ Shipments::CreateRemoteOrderService  asks the label service for a new label; the old request id no longer matches
ReturnMailer.moved                                  approved own-postage return only: the new posting address
```

A label return gets its new label the usual way: the callback ([label_return.md](label_return.md)) records it and emails it with `ReturnMailer.label_ready`. A submitted return has no label, no exchange hold and no posting instructions yet, so only its location changes.

## Key files

| File | Role |
| --- | --- |
| `app/models/location.rb`, `app/models/shop.rb` | Archived flag, default location, the fallback |
| `app/controllers/api/locations_controller.rb` | List, edit, archive, unarchive and make default |
| `app/services/return_orders/move_service.rb` | The move |
| `web/src/pages/Locations.tsx`, `web/src/pages/MoveReturnDialog.tsx` | The Locations page and the Move dialog |
| `test/services/move_return_test.rb`, `test/integration/locations_api_test.rb`, `e2e/tests/07-locations.spec.ts` | Tests |

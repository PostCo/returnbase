# Cancelling a Return

## Overview

A return can be cancelled while it is still `submitted` or `approved`: the `cancel` event in `ReturnOrder`'s state machine. Once the carrier has picked the parcel up (`in_transit`) or it has arrived, the return can no longer be cancelled.

Either side can cancel:

- **The merchant** presses **Cancel return** on the return page and confirms. The web app calls `POST /api/returns/:id/cancel`.
- **The shopper** presses **Cancel this return** on the status page, which is offered while the response says `can_cancel`. The web app calls `POST /api/shopper/returns/:number/cancel` with the shop and the email on the order, which finds the return the same way the status page does.

Both end in `ReturnOrders::CancelService`:

```
ReturnOrders::CancelService(return_order:, cancelled_by: :merchant | :shopper)   one transaction
  ├─ return_order.cancel!                  timeline: status_changed
  ├─ return_order.exchanges.destroy_all    releases the held stock (exchanges and their reservations)
  └─ timeline: cancelled, with who cancelled
ReturnMailer.cancelled                      after the transaction
```

A label that was already bought stays on the return as it is. The email tells the shopper not to send the parcel and that the label will not be used.

## Worked example

Harbour & Pine has one seeded return that its shopper cancelled after it was approved. To try it yourself:

1. Submit a return on the shopper page and approve it as the merchant.
2. Open the status page from the email link. **Cancel this return** is offered, and so is **Cancel return** on the merchant's page.
3. Cancel from either. The return shows Cancelled, its timeline says who cancelled, and Mailpit has "Your return R1xxx is cancelled".

## Key files

| File | Role |
| --- | --- |
| `app/services/return_orders/cancel_service.rb` | The cancel |
| `app/controllers/api/returns_controller.rb`, `app/controllers/api/shopper/returns_controller.rb` | The two endpoints |
| `app/views/return_mailer/cancelled.text.erb` | The shopper's email |
| `test/services/cancel_return_test.rb`, `e2e/tests/05-cancel.spec.ts` | Tests |

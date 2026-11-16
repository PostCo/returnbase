# 4. Polling StoreBox for updates

Date: 2026-05-26

## Status

Accepted

## Context

Once a return is at StoreBox, Returnbase needs to hear when the parcel arrives and how StoreBox graded each item. StoreBox sends no webhooks. Its API answers only when asked, with `GET /returns/:id` ([vendors/docs/storebox.md](../../vendors/docs/storebox.md)). Even a vendor that pushed updates would need a public URL to send them to, which every laptop and CI run would have to fake with a tunnel.

Returns spend days in a warehouse. Hearing about them a minute later costs nothing.

## Decision

Returnbase polls. `StoreBox::PollJob` runs every minute (`config/recurring.yml`). For each active StoreBox integration it reads every open `StoreBox::Return` (`pending` or `received`) with `GET /returns/:id` and hands the answer to `StoreBox::PollService`:

- StoreBox has the parcel: the return is received.
- StoreBox has graded every item: the merchant's result mapping picks one action for the whole return. `resolve` refunds and ships exchanges. `manual_review` leaves the return received for the merchant.

Polling the same answer twice changes nothing, because each step checks the return's current state first.

## Consequences

- Nothing has to reach Returnbase from outside, so local setup and CI need no tunnel.
- Updates arrive up to a minute late.
- It costs one request per open return per minute. That is fine at today's volumes. A merchant with thousands of returns in a warehouse would need a batch read, which StoreBox does not offer yet.
- A poll that fails is logged as a warning and tried again next minute. Nothing alerts anyone.
- Deactivated integrations are not polled ([0005](0005-storebox-activation-is-a-merchant-decision.md)).

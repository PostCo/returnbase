# 5. StoreBox activation is the merchant's decision

Date: 2026-06-30

## Status

Accepted

## Context

The first StoreBox build switched itself on as soon as setup was complete. Merchants map their locations one at a time, often before telling the warehouse what is coming, so the save that happened to finish the setup started sending returns to StoreBox while the merchant was still working through the page. There was also no way to turn StoreBox off without breaking the setup on purpose, and the next save would quietly turn it back on.

## Decision

Readiness and activation are separate.

- `StoreBoxIntegration::ReadinessService` answers one question: is the setup complete? StoreBox accepted the API key, at least one return location sends to a StoreBox warehouse, and every inspection result has an action.
- `StoreBoxIntegration::ActivateForm` is the only thing that sets `active`. It checks readiness and asks StoreBox about the key again first.
- The integration starts `connected`. Saving mappings (`UpdateForm`) never changes the status, and neither does replacing the key (`UpdateCredentialsForm`). `DeactivateForm` sets `disabled`, and Activate turns it back on with nothing to set up again.
- While StoreBox is active, the merchant cannot save away the last mapped location or clear a result's action. They deactivate first.

Only `active` acts. `ReturnOrders::SendToWarehouseService` sends only for an active integration, and `StoreBox::PollJob` polls only active ones.

Activation sends nothing by itself: returns that went past the send step before it stay where they are. Returns already at StoreBox when it is deactivated keep their `StoreBox::Return`, and their page tells the merchant to finish them by hand.

## Consequences

- A complete setup can sit unused. The settings page says so: "Setup is complete. StoreBox stays off until you activate it."
- There is no backfill. Activating StoreBox does not send returns approved earlier.
- After deactivation, returns at StoreBox stop moving on their own, even if StoreBox grades them.
- Code that asks "is StoreBox on?" must ask `active?`. Readiness means the setup is complete, nothing more.

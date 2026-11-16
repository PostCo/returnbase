# 2. ParcelDock is set up by support

Date: 2026-03-16

## Status

Accepted

## Context

ParcelDock was our first label provider after QuickPost. It sells the prepaid return label and its one facility, PD-01, receives the parcel. Lumen Home asked for it and wanted it running within the month.

The plan had two parts: an admin page so support could switch on the first shop straight away, and a merchant settings page (paste the API key, pick the facility location, switch it on) to follow. The admin page shipped. The merchant page was started and never finished. It was set aside when StoreBox took priority, and ParcelDock has not needed changing since.

## Decision

Support sets ParcelDock up at `/admin/parcel_dock` (`Admin::ParcelDockController`, behind HTTP basic auth). The page saves the API key, which location is the facility (the `parcel_dock_facility` flag), and whether ParcelDock is enabled. The merchant's Integrations page shows a ParcelDock card that tells them support manages it (`ParcelDockCard` in `web/src/pages/integrations/cards.tsx`).

There is no readiness check, no activation step and no credential check. Support checks the key by hand.

This is where the work stopped, not a product rule. Nothing about ParcelDock requires support to set it up, and nobody decided that merchants should not manage it.

## Consequences

- Every ParcelDock change is a support request.
- The admin page saves whatever key it is given and never checks it with ParcelDock. ParcelDock’s sandbox accepts any non-empty key, so in development a wrong key goes unnoticed; when ParcelDock does fail, the label comes back failed and the merchant has to request it again.
- `ParcelDockIntegration` has `enabled` and `disabled`, while StoreBox has `connected`, `active` and `disabled`. The two share no forms.
- Finishing the merchant page means giving ParcelDock the create, credentials, activate and deactivate forms StoreBox has ([0005](0005-storebox-activation-is-a-merchant-decision.md)) and retiring the admin page.

# AGENTS.md - Returnbase

The operating manual for anyone, person or agent, changing this repository. The web app has its own file, [web/AGENTS.md](web/AGENTS.md), which wins for `web/**`.

## 1. Working agreement

- Make the smallest change that solves the problem, and leave unrelated files alone.
- Read the flow doc and the decisions for the area before you change it. If the code and a doc disagree, the code is what runs. Fix the doc in the same change.
- Never commit secrets or `.env`.
- After a change, run the checks in section 6 that cover it, and say which ones you ran.

## 2. Repository map

| Path | What lives there |
| --- | --- |
| `app/models/` | ActiveRecord models. `ReturnOrder` and its state machine are the centre of everything |
| `app/models/store_box/` | StoreBox's own records: location and result mappings, sent returns, failed sends |
| `app/services/return_orders/`, `app/services/shipments/` | The return lifecycle: submit, approve, move, cancel, pick up, receive, resolve, refund, restock, exchange. `shipments/` asks the label service for labels and records its callbacks |
| `app/services/store_box/`, `app/services/store_box_integration/` | Sending to StoreBox, polling it, readiness |
| `app/forms/` | Validated multi-record changes, mostly integration settings |
| `app/jobs/` | Solid Queue jobs. Recurring ones are in `config/recurring.yml`, which the worker reads only when it starts: after changing it, run `docker compose restart worker` |
| `app/clients/` | One small HTTP client per vendor, on top of `VendorClient` |
| `app/controllers/api/` | The merchant API (login required) and `api/shopper/` (no login) |
| `app/controllers/webhooks/`, `app/controllers/admin/` | QuickPost's and the shipping service's webhooks, and support's ParcelDock page |
| `app/serializers/`, `app/mailers/`, `app/views/` | JSON shapes for the web app, shopper emails, the admin page |
| `db/seeds.rb` | The three demo shops. Read it to know what data you are looking at |
| `test/` | Minitest: `models/`, `services/` and `integration/` (HTTP) |
| `web/` | The merchant dashboard and shopper page (React, Vite, TypeScript) |
| `vendors/` | The fake QuickPost, StoreBox and ParcelDock, with their API docs |
| `shipping/` | The shipping team's label service, with its API docs. Returnbase engineers do not change it |
| `e2e/` | Playwright specs, run by `bin/e2e` |
| `docs/flows/`, `docs/decisions/`, `docs/glossary.md` | How flows work, why, and the vocabulary |

## 3. Running things

Everything runs in Docker Compose. Start with `bin/setup`, then `bin/verify`. The README lists the ports and logins.

- Rails commands: `docker compose exec api bin/rails <command>`, for example `console`, `test` or `db:migrate`.
- New migrations: `docker compose exec api bin/rails generate migration AddThingToThings`. Commit the regenerated `db/schema.rb`.
- Fresh data: `bin/reset`. Fresh vendors: `curl -X POST http://localhost:4100/reset`. Fresh label service: `curl -X POST http://localhost:4300/admin/reset`.
- Everything back to fresh at once, with a running stack: the "Demo data" section of the support page, http://localhost:5180/admin/parcel_dock. It empties the database, loads the seeds, and clears the vendors, the label service and Mailpit. The password is `returnbase-admin` locally. A deployment changes it with `DEMO_RESET_PASSWORD` in `.env`. Merchants who were logged in have to log in again.
- Logs: `docker compose logs -f api worker`. Jobs run in `worker`, so a send that never happens usually shows there.

## 4. Conventions

**Services.** Business logic lives in `app/services/<namespace>/<verb>_service.rb`, subclassing `ApplicationService` (`app/services/application_service.rb`). Keyword arguments go to `initialize`, and `#call` ends with `result(success:, payload:)`. Raise `Failure` with a message the merchant can read. Controllers call `Service.call`, which turns a `Failure` or an invalid record into a failed result with `errors`. Services call each other with `.call!`, which lets the error through so the outer transaction rolls back. `ReturnOrders::ApproveService` is the example to copy.

**Forms.** A change that validates across several records is a form in `app/forms/<model>/<action>_form.rb`: `ActiveModel::Validations`, a `#submit` that returns true or false, and messages on `errors`. Every StoreBox settings change is one (`app/forms/store_box_integration/`).

**Statuses and the state machine.** Status columns are integer enums with gaps between the values, so a new value fits between two others. `ReturnOrder`'s statuses and every allowed transition are in one block in `app/models/return_order.rb`, using `stateful_enum`. Change a return's status with its events (`approve!`, `cancel!`, `can_receive?`), never by assigning `status`.

**Timeline.** Every status change writes a `status_changed` event on its own (`app/models/return_order/timeline.rb`). Anything else the merchant should see on a return is `return_order.record_event(:kind, **data)`. A new kind goes in `TimelineEvent`'s enum and in `describe` in `web/src/pages/ReturnDetail.tsx`.

**Money.** Amounts are integer `*_cents` columns with a `currency`, wrapped by `monetize` from money-rails. Do arithmetic in cents. Refunds are simulated: a `Refund` row and an email, no payment provider.

**Shop settings.** Per-shop switches, such as `refund_on_carrier_pickup` and `restock_on_resolve`, are boolean columns on `Shop`. They are off by default, and the merchant changes them on the Settings page.

**Locations.** A merchant archives a location (`archived_at`) instead of deleting it, and returns already there keep it. New shopper returns go to `Shop#return_location`, which is the default location, or the first active location when the shop has none. `Location` uses flag_shih_tzu bits to say which integration owns a return location (`store_box_warehouse`, `parcel_dock_facility`). Query them with the generated scopes, such as `shop.locations.store_box_warehouse`. The next free bit is 3.

**Jobs.** Solid Queue on the main Postgres database ([decision 0001](docs/decisions/0001-solid-queue-on-postgres.md)). Jobs are thin and call one service. There are no automatic retries, so the service decides what a failure leaves behind.

**Vendor clients.** `app/clients/<vendor>_client.rb` subclasses `VendorClient`, takes its base URL from an environment variable with the Compose default, and has one method per endpoint. Any HTTP or network failure raises `VendorClient::Error`.

**Labels.** Label returns get their label from the shipping team's service in `shipping/`. Returnbase asks for the label and finishes the work when the service calls back ([decision 0008](docs/decisions/0008-labels-come-from-the-shipping-service.md)). Returnbase engineers do not change `shipping/`. A change to it goes through the shipping team.

**Integrations.** `Integration` is a single-table parent with encrypted credentials. A shop has at most one of each type, and each subclass defines its own `status` enum.

**Emails.** `ReturnMailer` sends the shopper plain-text emails with `deliver_now`, from the service that finished the step. Mailpit catches them.

## 5. How an integration is built

StoreBox is the fullest integration. [docs/flows/storebox_return.md](docs/flows/storebox_return.md) describes it end to end. Its layers:

1. A subclass of `Integration` with its status enum (`app/models/store_box_integration.rb`) and a module for its own records (`app/models/store_box/`).
2. A client in `app/clients/store_box_client.rb`, and the vendor's API notes in `vendors/docs/storebox.md`.
3. Forms for create, update, credentials, activate and deactivate, with readiness kept apart from activation ([decision 0005](docs/decisions/0005-storebox-activation-is-a-merchant-decision.md)).
4. A controller, routes and a serializer, the settings page, and its entries in `Api::IntegrationsController::AVAILABLE_TYPES` and `CARDS` in `web/src/pages/integrations/cards.tsx`.
5. The path out: `StoreBox::SendJob` sends an approved return, and a failed call is kept as a `StoreBox::SendAttempt`.
6. The path back: `StoreBox::PollJob` reads each open return and applies the merchant's result mapping.

ParcelDock, the other integration, is set up by support ([decision 0002](docs/decisions/0002-parceldock-is-set-up-by-support.md)).

## 6. Verifying a change

- **Rails tests.** `docker compose exec api bin/rails test`, or one file. Services are tested in `test/services/` against real records, with each vendor client swapped for a small fake (`test/test_helper.rb` and the test files).
- **Web.** `docker compose exec web npm run typecheck`.
- **The running app.** Do the flow in the dashboard as a merchant, then check what Returnbase actually sent in the vendor's request log (http://localhost:4100/storebox/log, `/quickpost/log`, `/parceldock/log`) and in the label service's console (http://localhost:4300). Play the vendor's side from its console. Shopper emails are in Mailpit.
- **Both shipping types.** Label and own-postage returns reach the same code by different paths. Try both, and try a shop without the integration.
- **End to end.** `bin/e2e` drives the main flows in a browser. Add a spec when you add a flow.
- **Everything.** `bin/verify`, which CI runs with `bin/e2e` on every pull request.

## 7. Before you change shared code

Shared code is anything more than one flow runs through: `ReturnOrder` and its state machine, the services in `app/services/return_orders/` and `app/services/shipments/`, the location flags, the shop settings, and the Manage Returns list and export. Widen the search before you narrow the change.

- Trace backward to every entry point that can create the state you are looking at: the shopper page, merchant actions, the QuickPost webhook, the label service's callback, the StoreBox poll, the seeds.
- Trace forward through events, services and jobs to where the return ends: resolved, refunded, emailed.
- Trace sideways through every caller and sibling that handles the same record or transition, including both shipping types, each integration and each shop setting.
- Read the tests, flow docs and decisions for the area.
- Back a claim that something does not exist ("nothing else sends this email") with a repository search, and say what you searched.

A plan or pull request that touches shared code says the lifecycle path (entry, change point, where it ends), the existing behaviour it reuses, the neighbouring paths it checked and left alone, and how each was verified.

## 8. Code comments

Default to none. Names, small methods and tests explain the code. Keep a comment only for what the code cannot say: a vendor's or platform's behaviour we cannot change, or why an odd choice is deliberate. Delete comments that narrate what the next line does.

## 9. Docs

- A decision someone will later ask "why?" about gets an ADR in `docs/decisions/`, numbered in order, with Date, Status, Context, Decision and Consequences.
- A change to how a return moves through an integration updates its flow doc in `docs/flows/`.
- New vocabulary goes in `docs/glossary.md`.

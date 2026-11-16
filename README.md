# Returnbase

Returnbase is a small returns platform for online shops. A shopper asks to return something, the merchant approves it, a carrier or the shopper posts the parcel, a warehouse receives and inspects it, and the merchant refunds or exchanges. It is modelled on how PostCo builds returns software, at a much smaller size: a Rails API, a React dashboard for merchants, and a shopper page.

Every outside system is simulated. There is no real Shopify store, carrier or warehouse. Orders and stock are seeded, and a small service in `vendors/` plays the carrier and the two warehouse integrations, with a console and a request log for each, so you can see every call Returnbase makes.

## Setup

You need Docker with Compose v2. Setup builds everything locally and takes about 10 minutes the first time.

**macOS and Linux.** Install Docker Desktop (macOS) or Docker Engine (Linux), then run:

```bash
git clone https://github.com/PostCo/returnbase.git
cd returnbase
bin/setup
bin/verify
```

**Windows.** Install [Docker Desktop](https://docs.docker.com/desktop/setup/install/windows-install/) and [Git for Windows](https://git-scm.com/downloads/win), which comes with Git Bash. Open Git Bash, clone the repository into any folder, and run the same four commands as above. Use Git Bash for `bin/setup` and `bin/verify`, because PowerShell and Command Prompt can't run them. Docker can't pass file changes from Windows folders into containers, so setup makes the dashboard check for changes on a timer. Expect pages to load more slowly than on macOS or Linux, because Docker reads Windows folders more slowly.

If that is too slow, use WSL2 with Docker Desktop's WSL integration. Open your Linux distribution (for example Ubuntu), clone inside the Linux filesystem, such as `~/returnbase`, never under `/mnt/c`, and run the same commands there. See Docker's [WSL2 best practices](https://docs.docker.com/desktop/features/wsl/best-practices/).

**Codespaces.** Open the repository in a Codespace. It runs `bin/setup` for you. When it finishes, run `bin/verify` in the terminal. The ports below are forwarded, so open them from the Ports tab.

`bin/verify` ends with `Setup verified. Your code: RB-xxxxxx`. Send us that code.

If setup fails, `docker compose ps` shows which service is unhealthy and `docker compose logs <service>` shows why.

## What runs where

| Service | URL | What it is |
| --- | --- | --- |
| Web | http://localhost:5180 | Merchant dashboard. The shopper page is http://localhost:5180/shopper |
| API | http://localhost:3100/api/health | Rails API. The web app reaches it through Vite's proxy at `/api` |
| Worker | none | Solid Queue: sends returns to StoreBox and polls it every minute |
| Vendors | http://localhost:4100 | The fake carrier and warehouses |
| Shipping | http://localhost:4300 | The shipping team's label service. Returnbase asks it for labels and it calls back. Its console shows every request |
| Mailpit | http://localhost:8125 | Every email Returnbase sends lands here |

## Logging in

Every seeded merchant's password is `returnbase`.

| Shop | Login | What it has |
| --- | --- | --- |
| Kopi Threads (MYR) | `owner@kopi-threads.example` | StoreBox active on both return locations, refund on carrier pickup and put items back in stock by default turned on, one StoreBox send that failed |
| Lumen Home (GBP) | `owner@lumen-home.example` | ParcelDock sells its prepaid labels |
| Harbour & Pine (USD) | `owner@harbour-pine.example` | No integrations, put items back in stock by default turned on, 9 return locations with Denver archived, one approved label return whose label failed, one return moved to another location |

Each shop has 44 orders, `#1001` to `#1044`, and 40 returns spread over every status. To file a return as a shopper, open http://localhost:5180/shopper, pick the shop, and use an order number with its customer's email from the table below.

### Orders and emails for the shopper page

Every shop has the same 12 customers, and each order belongs to the same customer in all three shops, so this table works everywhere. The seeds always produce the same data, so it stays right after `bin/reset`. Orders `#1041` to `#1044` have no returns yet. Any other order works too and gets a second return. An item offers an exchange when another size or colour of it is in stock at the shop's return location.

| Customer | Email | Orders |
| --- | --- | --- |
| Aisha Tan | aisha.tan@example.com | #1001, #1013, #1025, #1037 |
| Ben Okafor | ben.okafor@example.com | #1002, #1014, #1026, #1038 |
| Chloe Lindqvist | chloe.lindqvist@example.com | #1003, #1015, #1027, #1039 |
| Daniel Reyes | daniel.reyes@example.com | #1004, #1016, #1028, #1040 |
| Elena Hartley | elena.hartley@example.com | #1005, #1017, #1029, #1041 |
| Farid Novak | farid.novak@example.com | #1006, #1018, #1030, #1042 |
| Grace Ibrahim | grace.ibrahim@example.com | #1007, #1019, #1031, #1043 |
| Hiro Moreau | hiro.moreau@example.com | #1008, #1020, #1032, #1044 |
| Imani Singh | imani.singh@example.com | #1009, #1021, #1033 |
| Jonas Walsh | jonas.walsh@example.com | #1010, #1022, #1034 |
| Kavya Park | kavya.park@example.com | #1011, #1023, #1035 |
| Liam Costa | liam.costa@example.com | #1012, #1024, #1036 |

Support's ParcelDock page is http://localhost:5180/admin/parcel_dock, user `admin`, password `returnbase-admin`.

## The fake vendors

http://localhost:4100 links to each vendor's console and request log.

| Vendor | Plays | Console lets you |
| --- | --- | --- |
| QuickPost | The label carrier. Sends Returnbase a webhook on pickup and delivery | Mark a parcel picked up or delivered |
| StoreBox | A warehouse (WMS) that Returnbase sends returns to and polls | Mark a return received, then record an inspection result per item |
| ParcelDock | A label provider whose one facility receives the parcels | Mark a parcel picked up or delivered. ParcelDock sends no webhooks |

Each vendor also has a request log at `/<vendor>/log` (and `/<vendor>/log.json`), a scenario switch for failures such as `temporary_failure`, and a Reset button. The StoreBox API key is `sb_test_key`. API references live in [vendors/docs](vendors/docs), and [vendors/README.md](vendors/README.md) covers the rest. Vendor state is kept in memory, so restarting the `vendors` service clears it.

## The label service

Label returns get their label from the shipping team's service, not from the carrier directly. Approving a label return asks the service for a label and answers at once. The service creates the label a couple of seconds later and calls Returnbase back, and only then does the shopper get the label by email and the return go on to a warehouse. Its console at http://localhost:4300 lists every request, has a `carrier_failure` scenario that makes labels fail, and shows its log. The service belongs to the shipping team: [shipping/README.md](shipping/README.md).

## Day to day

```bash
bin/reset                                         # drop the database and load the seeds again
curl -X POST http://localhost:4100/reset          # clear all three fake vendors
curl -X POST http://localhost:4300/admin/reset    # clear the label service
docker compose exec api bin/rails console
docker compose logs -f api worker
```

`bin/reset` leaves the vendors, the label service and Mailpit alone. Clear Mailpit from its own page.

To put everything back at once, use "Demo data" on the support page (http://localhost:5180/admin/parcel_dock). Enter the reset password, `returnbase-admin` locally, and press "Reset all demo data". It empties the database and loads the seeds again, and clears the three fake vendors, the label service and Mailpit. Merchants who were logged in have to log in again. A deployment sets its own password with `DEMO_RESET_PASSWORD` in `.env`.

## Tests

```bash
bin/verify                                                        # service health, Rails tests and the web typecheck
docker compose exec api bin/rails test test/services/store_box_test.rb
docker compose exec web npm run typecheck
bin/e2e                                                           # Playwright, in a container, against the running stack
```

`bin/e2e` resets the database, the fake vendors, the label service and Mailpit before it runs, so it wipes whatever you changed in the demo data. Pass a spec to run one file, for example `bin/e2e tests/03-storebox.spec.ts`. The HTML report lands in `e2e/playwright-report/`. CI runs `bin/verify` and then `bin/e2e` on every pull request.

The vendors have their own contract tests. See [vendors/README.md](vendors/README.md).

## Where to read next

- [AGENTS.md](AGENTS.md) and [web/AGENTS.md](web/AGENTS.md): how the code is laid out and the conventions it follows.
- [docs/flows](docs/flows): how a return gets its label, goes through StoreBox or ParcelDock, is cancelled, or is moved to another location.
- [docs/decisions](docs/decisions): why things are the way they are.
- [docs/glossary.md](docs/glossary.md): the words we use.

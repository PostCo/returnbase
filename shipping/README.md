# Shipping label service

The label service owned by the shipping team. It buys return labels from the carriers (QuickPost and ParcelDock) on behalf of other teams' systems. Returnbase is one of its clients.

**Returnbase engineers do not change this folder.** It is the shipping team's service and lives here only so the whole system runs in one Compose stack. A change to its API or behaviour goes through the shipping team.

Its API is documented in [docs/api.md](docs/api.md).

## Running it

It runs as the `shipping` service in Docker Compose on port 4300. State lives in memory, so a restart or a reset starts clean.

- http://localhost:4300 is a small console: every label request, a scenario switch (`normal`, `carrier_failure`), a Reset button and the request log. The log is also at `/log.json`.
- `carrier_failure` makes every label request end as `failed`, as if the carrier had refused it.
- `SHIPPING_DELAY` (seconds, default 2) is how long a label takes to be created. `SHIPPING_CALLBACK_TOKEN` is the shared token sent on every callback. `VENDORS_URL` is where the carriers are.

Run its tests with:

```sh
cd shipping && bundle install && bundle exec ruby -Itest test/shipping_test.rb
```

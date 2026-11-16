# Fake vendors

One Sinatra service on port 4100 serves three fake vendors under separate paths. State lives in memory, so a restart or a reset starts clean.

| Vendor | Path | API reference |
| --- | --- | --- |
| StoreBox, warehouse, polled | `/storebox` | [docs/storebox.md](docs/storebox.md) |
| ParcelDock, combined label provider | `/parceldock` | [docs/parceldock.md](docs/parceldock.md) |
| QuickPost, label carrier with a webhook | `/quickpost` | [docs/quickpost.md](docs/quickpost.md) |

Each vendor has these sandbox controls, which are not part of its API:

- `/<vendor>/console` shows its records. StoreBox marks a return received and records item results. ParcelDock and QuickPost mark a parcel picked up or delivered.
- `/<vendor>/log` is the request log, and `/<vendor>/log.json` is the same data as JSON. QuickPost's log also lists its outgoing webhook calls.
- `POST /<vendor>/admin/scenario` with `scenario=<name>` sets the scenario. `POST /<vendor>/admin/reset` clears one vendor and `POST /reset` clears all three.

Scenarios: StoreBox has `normal`, `invalid_credentials` (every call answers 401) and `temporary_failure` (create answers 503). ParcelDock and QuickPost have `normal` and `temporary_failure`.

Credentials: StoreBox needs the key `sb_test_key` in `X-Api-Key`. ParcelDock takes any `X-Api-Key`. QuickPost takes any bearer token.

QuickPost's webhook goes to `QUICKPOST_WEBHOOK_URL`, which defaults to `http://api:3100/webhooks/quickpost`. Label URLs use `VENDORS_PUBLIC_URL`, which defaults to `http://localhost:4100` so a browser on the host can open them.

Run the contract tests with:

```sh
cd vendors && bundle install && bundle exec ruby -Itest -e 'Dir["test/*_test.rb"].each { |f| require "./" + f }'
```

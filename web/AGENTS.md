# AGENTS.md - Web app

Scope: `web/**`. Where this file and the root [AGENTS.md](../AGENTS.md) disagree for this folder, this file wins.

## 1. Stack

React 18, Vite 6, TypeScript 5, Tailwind CSS 4 through `@tailwindcss/vite`, Radix primitives, react-hook-form with zod, and react-router-dom 6. Do not upgrade any of them as part of a feature.

## 2. Layout

- `src/main.tsx` renders the shopper app for `/shopper/*` and the merchant app for everything else.
- `src/App.tsx` holds the merchant routes. Pages behind a login sit inside `RequireAuth` and `Layout`. Add a route there, and a link in `NAV` in `src/components/Layout.tsx` if it belongs in the sidebar.
- `src/pages/` holds one file per page, and the dialogs a page opens (`EditItemsDialog.tsx`, `MoveReturnDialog.tsx`, `ResolveDialog.tsx`). Integration pages live in `src/pages/integrations/`, with their types in `types.ts`.
- `src/shopper/` is the shopper page and status page. Its look is its own: `shopper.css`, scoped to `.shop` and coloured per shop by `themes.ts`, with the small components in `components.tsx`. It uses its own `shopperApi`, none of the merchant components, and no login.
- In development, Vite proxies `/api` and `/admin` to the Rails container (`vite.config.ts`), so the app always calls relative paths.

## 3. Components and look

The merchant look is a warm off-white canvas, white cards with hairline borders, Onest for text, JetBrains Mono for codes (return numbers, SKUs, tracking numbers) and one indigo accent. Colours, radii and fonts are CSS variables in `src/index.css`. Use the Tailwind classes that read them (`bg-card`, `text-muted-foreground`, `text-brand`, `rounded-card`, `font-mono`) and change a value there instead of writing a colour into a page. Any new screen, including a mockup for a new feature, is built from the components below and shows its loading, empty and error states.

Components in `src/components/ui/`, each small enough to read in one go:

- Actions: `Button` (`loading` shows a spinner and disables it), `DropdownMenu` (with radio items), `Tooltip`.
- Layout: `Card` (with `CardHeader`, `CardTitle`, `CardContent`, and `Dl` and `DlItem` for label and value pairs), `Table`, `Tabs`, `Dialog`.
- Form fields: `Input`, `SearchInput`, `Label`, `Select`, `Switch`.
- Status and feedback: `Badge` (`dot` for statuses), `Alert`, `Toast` (use `useToast()`), `Icon` (add a path to `PATHS` for a new icon).
- States: `Skeleton`, `TableSkeleton` and `CardSkeleton` while loading, `EmptyState` when there is nothing to show, `ErrorState` with a retry when a load fails, and `Pagination` under a paged table.

App-level pieces sit beside them in `src/components/`: `Layout` (sidebar with the shop name, and `PageHeader` with a back link, status badge, meta line and actions), `StatusBadge`, `FilterMenu` (a filter button that opens a menu), and `ConfirmButton` for any action that changes what Returnbase does on its own, such as activating an integration (`disabledReason` explains a disabled button on hover).

Rules for a page:

- Every page that loads data shows all four states. Loading is a skeleton shaped like the content. Empty says what is missing and what to do. Error uses `ErrorState` with `retry` from `useAsync`. While an action runs, its button shows `loading`.
- Join class names with `cn()` from `src/lib/utils.ts`. Badge variants carry meaning: `success`, `warning`, `danger`, `info`.
- Show the result of an action with `useToast()`. Show a failed load with `ErrorState`, not a bare line of text.
- Change a primitive only when every page should change with it. A new component goes in `ui/` if two pages can use it.

## 4. Data

- Call the API with `api<T>(path, { method, body })` from `src/lib/api.ts`. It sends JSON with the session cookie, throws `ApiError` with the server's `errors` array, and logs the merchant out on a 401.
- Load page data with `useAsync(load, deps)` from `src/lib/use-async.ts`, which returns `{ data, setData, error, pending, retry }`. `data` is null until the first load, `pending` is true while a request runs, and `retry` runs it again.
- Action endpoints answer with the updated record. Put it straight into state with `setData` instead of loading again (see `run` in `src/pages/ReturnDetail.tsx`).
- Response types live in `src/lib/types.ts` and `src/pages/integrations/types.ts`, and mirror the serializers in `app/serializers/`. Change both sides together.

## 5. Forms

- Use react-hook-form with `zodResolver` and a zod schema next to the component (`src/pages/Login.tsx` is the small example, `src/pages/integrations/StoreBoxSettings.tsx` the large one).
- Radix `Select` and `Switch` need a `Controller`.
- Show server errors where the merchant is looking: `setError` on the field for a rejected value, or a line beside the submit button for the whole form.
- Disable the submit button while submitting, and when nothing has changed if the form edits saved settings.

## 6. Copy

Write for a merchant running a shop. Say what will happen to their returns, in their words. Keep implementation terms (job, poll, API) out of the page unless the merchant needs them to act.

## 7. Verifying

- `docker compose exec web npm run typecheck`. There is no unit test runner for the web app.
- Open the page at http://localhost:5180 and do the flow, including the failure you handled.
- `bin/e2e` covers the main flows. The specs find elements by role, label and a few `data-testid`s (`shop-name`, `page-header`, `timeline`, `store-box-panel`, `shipment-status`, `shipment-tracking`, `return-location`, `integration-<Name>`, `return-submitted`, `status`). Keep those working when you change a page, or update the spec in the same change.

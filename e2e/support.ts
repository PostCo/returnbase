import { expect, type APIRequestContext, type Locator, type Page } from "@playwright/test";

export const MAILPIT_URL = process.env.MAILPIT_URL ?? "http://localhost:8125";
export const VENDORS_URL = process.env.VENDORS_URL ?? "http://localhost:4100";
export const SHIPPING_URL = process.env.SHIPPING_URL ?? "http://localhost:4300";

export const PASSWORD = "returnbase";
export const SHOPS = {
  kopi: { name: "Kopi Threads", email: "owner@kopi-threads.example" },
  lumen: { name: "Lumen Home", email: "owner@lumen-home.example" },
  harbour: { name: "Harbour & Pine", email: "owner@harbour-pine.example" },
};
type Shop = (typeof SHOPS)[keyof typeof SHOPS];
type Shipping = "Prepaid label" | "Post it yourself";
type OrderPick = { orderNumber: string; email: string; sku: string; exchangeSku?: string };
type LookupItem = { sku: string; exchange_options: { sku: string }[] };

export async function logIn(page: Page, shop: Shop) {
  await page.goto("/login");
  await page.getByLabel("Email").fill(shop.email);
  await page.getByLabel("Password").fill(PASSWORD);
  await page.getByRole("button", { name: "Log in" }).click();
  await expect(page.getByTestId("shop-name")).toHaveText(shop.name);
}

// An order the shopper can return, found through the merchant's return list and the shopper lookup. Needs a merchant login.
export async function findOrder(page: Page, shop: Shop, { exchange = false } = {}): Promise<OrderPick> {
  const { shops } = await (await page.request.get("/api/shopper/shops")).json();
  const shopId = shops.find((s: { name: string }) => s.name === shop.name).id;
  const { returns } = await (await page.request.get("/api/returns")).json();
  for (const { order, customer } of returns) {
    const lookup = await page.request.post("/api/shopper/lookup", {
      data: { shop_id: shopId, order_number: order.number, email: customer.email },
    });
    const items: LookupItem[] = (await lookup.json()).items;
    const item = exchange ? items.find((i) => i.exchange_options.length > 0) : items[0];
    if (item) {
      return { orderNumber: order.number, email: customer.email, sku: item.sku, exchangeSku: exchange ? item.exchange_options[0].sku : undefined };
    }
  }
  throw new Error(`No order at ${shop.name} has an item to return${exchange ? " for an exchange" : ""}`);
}

export async function submitReturn(page: Page, shop: Shop, pick: OrderPick, shipping: Shipping) {
  // The page loads its shop list on mount and selects the first shop, so let that settle before choosing one.
  await page.goto("/shopper", { waitUntil: "networkidle" });
  await page.getByLabel("Shop").selectOption({ label: shop.name });
  await expect(page.getByLabel("Shop").locator("option:checked")).toHaveText(shop.name);
  await page.getByLabel("Order number").fill(pick.orderNumber);
  await page.getByLabel("Email on the order").fill(pick.email);
  await page.getByRole("button", { name: "Find my order" }).click();

  const item = page.locator("fieldset", { hasText: pick.sku });
  await item.getByRole("checkbox").check();
  if (pick.exchangeSku) {
    await item.getByLabel("An exchange").check();
    await item.getByLabel("Exchange for").selectOption(pick.exchangeSku);
  }
  await page.getByRole("button", { name: "Continue" }).click();
  await page.getByLabel(shipping).check();
  await page.getByRole("button", { name: "Submit return" }).click();

  const submitted = page.getByTestId("return-submitted");
  await expect(submitted).toBeVisible();
  const number = (await submitted.locator("strong").textContent()) ?? "";
  const statusUrl = (await submitted.getByRole("link", { name: "See its status" }).getAttribute("href")) ?? "";
  return { number, statusUrl };
}

export async function openReturn(page: Page, number: string) {
  await page.goto("/returns");
  await page.getByLabel("Search returns").fill(number);
  await page.getByRole("link", { name: number, exact: true }).click();
  await expect(page.getByRole("heading", { name: `Return ${number}` })).toBeVisible();
}

// The heading, status badge and action buttons at the top of a page.
export function pageHeader(page: Page) {
  return page.getByTestId("page-header");
}

export async function act(page: Page, button: string, status: string) {
  await pageHeader(page).getByRole("button", { name: button, exact: true }).click();
  await expect(pageHeader(page).getByText(status, { exact: true })).toBeVisible();
}

// Resolve opens a dialog with one row per item. By default every item is accepted with its default restock choice.
export async function resolveReturn(page: Page, { status = "Resolved", decide }: { status?: string; decide?: () => Promise<void> } = {}) {
  await pageHeader(page).getByRole("button", { name: "Resolve", exact: true }).click();
  await expect(page.getByRole("dialog")).toBeVisible();
  await decide?.();
  await page.getByRole("dialog").getByRole("button", { name: /^(Resolve|Reject) return$/ }).click();
  await expect(pageHeader(page).getByText(status, { exact: true })).toBeVisible();
}

export async function choose(page: Page, select: string, option: string) {
  await page.getByRole("combobox", { name: select }).click();
  await page.getByRole("option", { name: option, exact: true }).click();
}

// A filter menu on the returns list, such as Shipping or StoreBox.
export async function filter(page: Page, menu: string, option: string) {
  await page.getByRole("button", { name: new RegExp(`^${menu}\\b`) }).click();
  await page.getByRole("menuitemradio", { name: option, exact: true }).click();
}

export async function expectEmail(request: APIRequestContext, to: string, subject: string) {
  type Message = { Subject: string; To: { Address: string }[] };
  await expect
    .poll(
      async () => {
        const { messages } = await (await request.get(`${MAILPIT_URL}/api/v1/messages?limit=500`)).json();
        return (messages as Message[]).some((m) => m.Subject === subject && m.To.some((t) => t.Address === to));
      },
      { message: `Mailpit has "${subject}" for ${to}` },
    )
    .toBe(true);
}

export async function setScenario(request: APIRequestContext, vendor: "storebox" | "parceldock" | "quickpost", scenario: string) {
  const response = await request.post(`${VENDORS_URL}/${vendor}/admin/scenario`, { data: { scenario } });
  expect(response.ok()).toBe(true);
}

export async function setShippingScenario(request: APIRequestContext, scenario: "normal" | "carrier_failure") {
  const response = await request.post(`${SHIPPING_URL}/admin/scenario`, { data: { scenario } });
  expect(response.ok()).toBe(true);
}

// The page does not refresh itself, so reload until a background step (a label callback, a worker job) shows its result.
export async function reloadUntilVisible(page: Page, target: Locator) {
  await expect(async () => {
    await page.reload();
    await expect(target).toBeVisible({ timeout: 1_000 });
  }).toPass({ timeout: 30_000 });
}

// The shipping service creates the label in the background and calls back, so a return shows its label a moment after approval.
export async function waitForLabel(page: Page) {
  await reloadUntilVisible(page, page.getByRole("link", { name: "Open label" }));
}

// References of the returns a vendor accepted, read from its request log.
export async function vendorCreates(request: APIRequestContext, vendor: "storebox" | "parceldock", path: string): Promise<string[]> {
  type Entry = { method: string; path: string; status: number; body: string };
  const { requests } = await (await request.get(`${VENDORS_URL}/${vendor}/log.json`)).json();
  return (requests as Entry[])
    .filter((entry) => entry.method === "POST" && entry.path === path && entry.status === 201)
    .map((entry) => JSON.parse(entry.body).reference);
}

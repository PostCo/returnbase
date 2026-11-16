import { expect, test, type Page } from "@playwright/test";
import { act, choose, filter, findOrder, logIn, openReturn, pageHeader, setScenario, SHOPS, submitReturn, vendorCreates } from "../support";

// Harbour & Pine starts with no StoreBox. Each test builds on the one before.
const shop = SHOPS.harbour;
test.describe.configure({ mode: "serial" });

let sentReturn = "";

test.afterAll(async ({ request }) => {
  await setScenario(request, "storebox", "normal");
});

// StoreBox::SendJob runs on the worker, so the panel appears a moment after approval.
async function expectStoreBoxPanel(page: Page, text: string) {
  await expect(async () => {
    await page.reload();
    await expect(page.getByTestId("store-box-panel")).toContainText(text, { timeout: 2_000 });
  }).toPass({ timeout: 30_000 });
}

test("the merchant connects, maps and activates StoreBox, and saving alone leaves it off", async ({ page }) => {
  await logIn(page, shop);
  await page.getByRole("link", { name: "Integrations" }).click();
  const card = page.getByTestId("integration-StoreBox");
  await expect(card).toContainText("Not connected");
  await card.getByRole("link", { name: "Set up" }).click();

  await page.getByLabel("API key").fill("not-a-storebox-key");
  await page.getByRole("button", { name: "Connect" }).click();
  await expect(page.getByText("StoreBox did not accept this API key")).toBeVisible();
  await page.getByLabel("API key").fill("sb_test_key");
  await page.getByRole("button", { name: "Connect" }).click();

  await expect(page.getByText("1 of 3 done")).toBeVisible();
  await expect(pageHeader(page).getByRole("button", { name: "Activate" })).toBeDisabled();

  await choose(page, "StoreBox warehouse for Portland Returns", "Rotterdam Main (NL)");
  await choose(page, "Action for Restock", "Resolve (refund or exchange)");
  await choose(page, "Action for Damaged", "Leave for manual review");
  await choose(page, "Action for Wrong item", "Leave for manual review");
  await page.getByRole("button", { name: "Save settings" }).click();

  await expect(page.getByText("3 of 3 done")).toBeVisible();
  await expect(page.getByText("Setup is complete. StoreBox stays off until you activate it.")).toBeVisible();
  await expect(pageHeader(page).getByText("Connected, not active", { exact: true })).toBeVisible();

  await pageHeader(page).getByRole("button", { name: "Activate" }).click();
  await page.getByRole("dialog").getByRole("button", { name: "Activate" }).click();
  await expect(pageHeader(page).getByText("Active", { exact: true })).toBeVisible();
});

test("an approved own-postage return and an approved label return both go to StoreBox", async ({ page }) => {
  await logIn(page, shop);
  const order = await findOrder(page, shop);
  const ownPostage = await submitReturn(page, shop, order, "Post it yourself");
  const label = await submitReturn(page, shop, order, "Prepaid label");

  for (const { number } of [ownPostage, label]) {
    await openReturn(page, number);
    await act(page, "Approve", "Approved");
    await expectStoreBoxPanel(page, "Expected at StoreBox");
  }
  expect(await vendorCreates(page.request, "storebox", "/storebox/returns")).toEqual(
    expect.arrayContaining([ownPostage.number, label.number]),
  );
  sentReturn = ownPostage.number;
});

test("a failed send stays on the return and in the filter until Retry sends it", async ({ page }) => {
  await setScenario(page.request, "storebox", "temporary_failure");
  await logIn(page, shop);
  const order = await findOrder(page, shop);
  const { number } = await submitReturn(page, shop, order, "Post it yourself");

  await openReturn(page, number);
  await act(page, "Approve", "Approved");
  await expectStoreBoxPanel(page, "Send failed");
  await expect(page.getByTestId("store-box-panel")).toContainText("StoreBox is temporarily unavailable");

  await page.goto("/returns");
  await filter(page, "StoreBox", "StoreBox send failed");
  await expect(page.locator("tbody tr")).toHaveCount(1);
  await page.getByRole("link", { name: number, exact: true }).click();

  await setScenario(page.request, "storebox", "normal");
  await page.getByRole("button", { name: "Retry send" }).click();
  const panel = page.getByTestId("store-box-panel");
  await expect(panel).toContainText("Expected at StoreBox");
  await expect(panel).toContainText("after 1 failed attempt");

  await page.goto("/returns?store_box=send_failed");
  await expect(page.getByText("No returns match these filters.")).toBeVisible();
});

test("deactivating StoreBox leaves sent returns on their pages for the merchant to finish", async ({ page }) => {
  await logIn(page, shop);
  await page.goto("/integrations/store-box");
  await pageHeader(page).getByRole("button", { name: "Deactivate" }).click();
  await page.getByRole("dialog").getByRole("button", { name: "Deactivate" }).click();
  await expect(pageHeader(page).getByText("Deactivated", { exact: true })).toBeVisible();

  await openReturn(page, sentReturn);
  await expect(page.getByTestId("store-box-panel")).toContainText("StoreBox is deactivated, so Returnbase no longer checks it for updates.");
  await act(page, "Mark received", "Received");
});

import { expect, test, type Page } from "@playwright/test";
import { act, choose, expectEmail, findOrder, logIn, openReturn, pageHeader, resolveReturn, SHOPS, submitReturn, VENDORS_URL } from "../support";

// Harbour & Pine restocks on resolve in the seeds. StoreBox was deactivated by the StoreBox spec.
const shop = SHOPS.harbour;
test.describe.configure({ mode: "serial" });

async function resolveOwnPostageReturn(page: Page, number: string) {
  await openReturn(page, number);
  await act(page, "Approve", "Approved");
  await act(page, "Mark received", "Received");
  await resolveReturn(page);
}

test("the Settings page shows the restock default and keeps a change", async ({ page }) => {
  await logIn(page, shop);
  await page.getByRole("link", { name: "Settings" }).click();
  const restock = page.getByLabel("Put items back in stock by default");
  await expect(restock).toBeChecked();

  await restock.click();
  await expect(page.getByText("Settings saved", { exact: true })).toBeVisible();
  await page.reload();
  await expect(restock).not.toBeChecked();

  await restock.click();
  await page.reload();
  await expect(restock).toBeChecked();
});

test("resolving a return puts the items back in stock", async ({ page }) => {
  await logIn(page, shop);
  const order = await findOrder(page, shop);
  const stockAfter: number[] = [];

  for (let attempt = 0; attempt < 2; attempt++) {
    const { number } = await submitReturn(page, shop, order, "Post it yourself");
    await resolveOwnPostageReturn(page, number);
    const text = (await page.getByTestId("timeline").getByText(/^Restocked 1 x /).textContent()) ?? "";
    stockAfter.push(Number(/\((\d+) available\)/.exec(text)?.[1]));
  }
  expect(stockAfter[1]).toBe(stockAfter[0] + 1);
});

test("an item StoreBox grades as damaged is not restocked", async ({ page }) => {
  test.setTimeout(180_000);
  await logIn(page, shop);
  await page.goto("/integrations/store-box");
  await expect(page.getByRole("switch", { name: "Back in stock for Restock" })).toBeChecked();
  await expect(page.getByRole("switch", { name: "Back in stock for Damaged" })).not.toBeChecked();
  await pageHeader(page).getByRole("button", { name: "Activate" }).click();
  await page.getByRole("dialog").getByRole("button", { name: "Activate" }).click();
  await expect(pageHeader(page).getByText("Active", { exact: true })).toBeVisible();

  const order = await findOrder(page, shop);
  const { number } = await submitReturn(page, shop, order, "Post it yourself");
  await openReturn(page, number);
  await act(page, "Approve", "Approved");
  await expect(async () => {
    await page.reload();
    await expect(page.getByTestId("store-box-panel")).toContainText("Expected at StoreBox", { timeout: 2_000 });
  }).toPass({ timeout: 30_000 });

  await page.goto(`${VENDORS_URL}/storebox/console`);
  const row = page.locator("tr", { hasText: number });
  await row.getByRole("button", { name: "Mark received" }).click();
  await row.getByRole("combobox").selectOption("damaged");
  await row.getByRole("button", { name: "Record results" }).click();

  await openReturn(page, number);
  await expect(async () => {
    await page.reload();
    await expect(page.getByTestId("timeline")).toContainText("StoreBox inspected the items", { timeout: 2_000 });
  }).toPass({ timeout: 120_000 });
  await expect(page.getByText("Not restockable")).toBeVisible();

  await pageHeader(page).getByRole("button", { name: "Resolve", exact: true }).click();
  await expect(page.getByRole("dialog").getByLabel("Put back in stock")).not.toBeChecked();
  await page.getByRole("dialog").getByRole("button", { name: "Resolve return" }).click();
  await expect(pageHeader(page).getByText("Resolved", { exact: true })).toBeVisible();
  await expect(page.getByTestId("timeline").getByText(/^Nothing restocked; not restocked: 1 x /)).toBeVisible();
});

test("an accepted item left unticked is not put back in stock", async ({ page }) => {
  await logIn(page, shop);
  const order = await findOrder(page, shop);
  const { number } = await submitReturn(page, shop, order, "Post it yourself");
  await openReturn(page, number);
  await act(page, "Approve", "Approved");
  await act(page, "Mark received", "Received");

  await resolveReturn(page, {
    decide: async () => {
      await expect(page.getByRole("dialog").getByLabel("Put back in stock")).toBeChecked();
      await page.getByRole("dialog").getByLabel("Put back in stock").uncheck();
    },
  });
  await expect(page.getByTestId("timeline").getByText(/^Nothing restocked; not restocked: 1 x /)).toBeVisible();
  await expect(page.getByRole("cell", { name: /Accepted.*Not put back in stock/ })).toBeVisible();
});

test("rejecting the only item in the Resolve dialog rejects the return and emails the shopper", async ({ page }) => {
  await logIn(page, shop);
  const order = await findOrder(page, shop);
  const { number, statusUrl } = await submitReturn(page, shop, order, "Post it yourself");
  await openReturn(page, number);
  await act(page, "Approve", "Approved");
  await act(page, "Mark received", "Received");

  await resolveReturn(page, {
    status: "Rejected",
    decide: async () => {
      await choose(page, "Decision for", "Reject");
      await expect(page.getByRole("dialog").getByRole("button", { name: "Reject return" })).toBeVisible();
    },
  });
  await expect(page.getByTestId("timeline")).toContainText("Rejected 1 x ");
  await expect(page.getByTestId("timeline")).not.toContainText("Restocked");
  await expect(page.getByRole("cell", { name: "Rejected", exact: true })).toBeVisible();
  await expectEmail(page.request, order.email, "Your return " + number + " was not accepted");

  await page.goto(statusUrl);
  await expect(page.getByTestId("status")).toHaveText("rejected");
  await expect(page.getByText("(Not accepted)")).toBeVisible();
});

test("the Reject button on a received return asks first, then rejects every item", async ({ page }) => {
  await logIn(page, shop);
  const order = await findOrder(page, shop);
  const { number } = await submitReturn(page, shop, order, "Post it yourself");
  await openReturn(page, number);
  await act(page, "Approve", "Approved");
  await act(page, "Mark received", "Received");

  await pageHeader(page).getByRole("button", { name: "Reject", exact: true }).click();
  await page.getByRole("dialog").getByRole("button", { name: "Reject return" }).click();
  await expect(pageHeader(page).getByText("Rejected", { exact: true })).toBeVisible();
  await expect(page.getByRole("cell", { name: "Rejected", exact: true })).toBeVisible();
  await expectEmail(page.request, order.email, "Your return " + number + " was not accepted");
});

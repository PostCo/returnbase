import { expect, test } from "@playwright/test";
import { act, expectEmail, findOrder, logIn, openReturn, pageHeader, SHOPS, submitReturn, waitForLabel } from "../support";

// Harbour & Pine has no integrations, so these returns take the plain flow.
const shop = SHOPS.harbour;

test("a merchant cancels an approved exchange return and releases its stock", async ({ page }) => {
  await logIn(page, shop);
  const order = await findOrder(page, shop, { exchange: true });
  const { number } = await submitReturn(page, shop, order, "Prepaid label");

  await openReturn(page, number);
  await act(page, "Approve", "Approved");
  await waitForLabel(page);
  await expect(page.getByText(`Exchange ${order.exchangeSku} (reserved)`)).toBeVisible();

  await pageHeader(page).getByRole("button", { name: "Cancel return" }).click();
  await page.getByRole("dialog").getByRole("button", { name: "Cancel return" }).click();

  await expect(pageHeader(page).getByText("Cancelled", { exact: true })).toBeVisible();
  await expect(pageHeader(page).getByRole("button", { name: "Cancel return" })).toHaveCount(0);
  await expect(page.getByText(`Exchange ${order.exchangeSku}`)).toHaveCount(0);
  await expect(page.getByTestId("timeline")).toContainText("Cancelled by the merchant");
  await expect(page.getByRole("link", { name: "Open label" })).toBeVisible();
  await expectEmail(page.request, order.email, `Your return ${number} is cancelled`);
});

test("a shopper cancels their own submitted return from the status page", async ({ page }) => {
  await logIn(page, shop);
  const order = await findOrder(page, shop);
  const { number, statusUrl } = await submitReturn(page, shop, order, "Post it yourself");

  await page.goto(statusUrl);
  page.once("dialog", (dialog) => dialog.accept());
  await page.getByRole("button", { name: "Cancel this return" }).click();

  await expect(page.getByTestId("status")).toHaveText("cancelled");
  await expect(page.getByRole("button", { name: "Cancel this return" })).toHaveCount(0);
  await expectEmail(page.request, order.email, `Your return ${number} is cancelled`);

  await openReturn(page, number);
  await expect(page.getByTestId("timeline")).toContainText("Cancelled by the shopper");
});

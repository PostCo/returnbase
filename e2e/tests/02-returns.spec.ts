import { readFileSync } from "node:fs";
import { expect, test } from "@playwright/test";
import {
  act, expectEmail, filter, findOrder, logIn, MAILPIT_URL, openReturn, pageHeader, resolveReturn, SHOPS, submitReturn, VENDORS_URL, waitForLabel,
} from "../support";

// Harbour & Pine has no integrations, so these returns take the plain flow.
const shop = SHOPS.harbour;

test("a prepaid-label return is picked up by the carrier, received and refunded", async ({ page }) => {
  await logIn(page, shop);
  const order = await findOrder(page, shop);
  const { number, statusUrl } = await submitReturn(page, shop, order, "Prepaid label");
  await expectEmail(page.request, order.email, `We received your return ${number}`);

  await openReturn(page, number);
  await act(page, "Approve", "Approved");
  await expect(page.getByTestId("shipment-status")).toHaveText("Label requested");
  await waitForLabel(page);
  const tracking = (await page.getByTestId("shipment-tracking").textContent()) ?? "";
  expect(tracking).toMatch(/^QP\d+$/);
  await expect(page.getByRole("link", { name: "Open label" })).toHaveAttribute("href", new RegExp(`/quickpost/labels/${tracking}$`));
  await expectEmail(page.request, order.email, `Your return ${number} is approved`);
  await expectEmail(page.request, order.email, `Your prepaid label for return ${number}`);

  await page.goto(`${VENDORS_URL}/quickpost/console`);
  const parcel = page.locator("tr", { hasText: tracking });
  await parcel.getByRole("button", { name: "Mark picked up" }).click();
  await expect(parcel).toContainText("picked_up");

  await openReturn(page, number);
  await expect(pageHeader(page).getByText("In transit", { exact: true })).toBeVisible();
  await act(page, "Mark received", "Received");
  await resolveReturn(page);
  await expect(page.getByText(/^Refunded /)).toBeVisible();
  await expectEmail(page.request, order.email, `Your refund for return ${number}`);

  await page.goto(statusUrl);
  await expect(page.getByTestId("status")).toHaveText("resolved");
  await expect(page.getByText(/^Refunded /)).toBeVisible();

  await page.goto(MAILPIT_URL);
  await expect(page.getByText(`Your refund for return ${number}`)).toBeVisible();
});

test("an own-postage exchange holds stock on approval and ships the replacement on resolve", async ({ page }) => {
  await logIn(page, shop);
  const order = await findOrder(page, shop, { exchange: true });
  const { number, statusUrl } = await submitReturn(page, shop, order, "Post it yourself");

  await openReturn(page, number);
  await act(page, "Approve", "Approved");
  await expect(page.getByText(`Exchange ${order.exchangeSku} (reserved)`)).toBeVisible();
  await expect(page.getByText("No shipment yet.")).toBeVisible();

  await page.goto(statusUrl);
  await expect(page.getByText(/^Post your parcel to /)).toBeVisible();

  await openReturn(page, number);
  await act(page, "Mark received", "Received");
  await resolveReturn(page);
  await expect(page.getByText(`Exchange ${order.exchangeSku} (fulfilled)`)).toBeVisible();

  for (const subject of [
    `We received your return ${number}`,
    `Your return ${number} is approved`,
    `Your exchange for return ${number} is on its way`,
  ]) {
    await expectEmail(page.request, order.email, subject);
  }
});

test("Manage Returns filters and the CSV export list the same returns", async ({ page }) => {
  await logIn(page, shop);
  const { total } = await (await page.request.get("/api/returns?status=resolved&shipping=own_postage")).json();
  expect(total).toBeGreaterThan(0);

  await page.getByRole("tab", { name: "Resolved" }).click();
  await filter(page, "Shipping", "Own postage");
  await expect(page.getByText(`${total} returns`)).toBeVisible();
  const rows = page.locator("tbody tr");
  await expect(rows).toHaveCount(total);
  await expect(rows.filter({ hasNotText: "Resolved" })).toHaveCount(0);
  await expect(rows.filter({ hasNotText: "Own postage" })).toHaveCount(0);

  const download = page.waitForEvent("download");
  await page.getByRole("link", { name: "Export CSV" }).click();
  const [header, ...lines] = readFileSync((await (await download).path()) ?? "", "utf8").trim().split("\n");
  expect(header).toBe("Order,Return,Status,Customer,Email,Shipping type,StoreBox status,Created,Items");
  expect(lines).toHaveLength(total);
  for (const line of lines) {
    const cells = line.split(",");
    expect([cells[2], cells[5]]).toEqual(["resolved", "own_postage"]);
  }
});

import { expect, test } from "@playwright/test";
import { act, findOrder, logIn, openReturn, SHOPS, submitReturn, vendorCreates, VENDORS_URL, waitForLabel } from "../support";

// Lumen Home buys its labels from ParcelDock. Support manages that at /admin/parcel_dock.
const shop = SHOPS.lumen;
test.use({ httpCredentials: { username: "admin", password: "returnbase-admin" } });

test("support sets up ParcelDock, and a label return gets its label from ParcelDock", async ({ page }) => {
  await page.goto("/admin/parcel_dock");
  const row = page.locator("tr", { hasText: shop.name });
  await row.getByLabel("Enabled").uncheck();
  await row.getByRole("button", { name: "Save" }).click();
  await expect(page.getByText(`Saved ParcelDock for ${shop.name}`)).toBeVisible();
  await expect(row.locator("td").nth(1)).toHaveText("disabled");
  await row.getByLabel("Facility location").selectOption({ label: "ParcelDock PD-01" });
  await row.getByLabel("Enabled").check();
  await row.getByRole("button", { name: "Save" }).click();
  await expect(row.locator("td").nth(1)).toHaveText("enabled");

  await logIn(page, shop);
  await page.getByRole("link", { name: "Integrations" }).click();
  const card = page.getByTestId("integration-ParcelDock");
  await expect(card).toContainText("Enabled");
  await expect(card).toContainText("Returnbase support manages this integration");

  const order = await findOrder(page, shop);
  const { number, statusUrl } = await submitReturn(page, shop, order, "Prepaid label");
  await openReturn(page, number);
  await act(page, "Approve", "Approved");
  await waitForLabel(page);
  await expect(page.getByTestId("return-location")).toHaveText("ParcelDock PD-01");
  const tracking = (await page.getByTestId("shipment-tracking").textContent()) ?? "";
  expect(tracking).toMatch(/^PD\d+$/);
  expect(await vendorCreates(page.request, "parceldock", "/parceldock/shipments")).toContain(number);

  await page.goto(statusUrl);
  await expect(page.getByRole("link", { name: "Print your prepaid label" })).toHaveAttribute(
    "href",
    new RegExp(`/parceldock/labels/${tracking}$`),
  );
  const label = await page.request.get(`${VENDORS_URL}/parceldock/labels/${tracking}`);
  expect(await label.text()).toContain(tracking);
});

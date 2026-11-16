import { expect, test } from "@playwright/test";
import { act, choose, expectEmail, findOrder, logIn, openReturn, pageHeader, SHOPS, submitReturn, waitForLabel } from "../support";

// Harbour & Pine: new returns go to its default, Portland Returns.
const shop = SHOPS.harbour;

test("a merchant edits and archives a location, and moves a label return and an own-postage return", async ({ page }) => {
  await logIn(page, shop);

  await page.goto("/locations");
  const austin = page.getByRole("row", { name: /Austin Returns/ });
  await page.getByRole("button", { name: "Edit Austin Returns" }).click();
  await page.getByLabel("Address").fill("99 Congress Avenue, Austin");
  await page.getByRole("button", { name: "Save location" }).click();
  await expect(austin).toContainText("99 Congress Avenue, Austin");

  const portland = page.getByRole("row", { name: /Portland Returns/ });
  await expect(portland).toContainText("Default");
  await expect(portland.getByRole("button", { name: "Archive" })).toHaveCount(0);

  await austin.getByRole("button", { name: "Archive" }).click();
  await page.getByRole("dialog").getByRole("button", { name: "Archive" }).click();
  await expect(austin).toContainText("Archived");

  const labelOrder = await findOrder(page, shop);
  const label = await submitReturn(page, shop, labelOrder, "Prepaid label");
  await openReturn(page, label.number);
  await expect(page.getByTestId("return-location")).toHaveText("Portland Returns");
  await act(page, "Approve", "Approved");
  await waitForLabel(page);
  const firstTracking = (await page.getByTestId("shipment-tracking").textContent()) ?? "";

  await pageHeader(page).getByRole("button", { name: "Move" }).click();
  await page.getByRole("combobox", { name: "New location" }).click();
  await expect(page.getByRole("option", { name: "Austin Returns" })).toHaveCount(0);
  await page.getByRole("option", { name: "Boston Returns", exact: true }).click();
  await page.getByRole("button", { name: "Move return" }).click();

  await expect(page.getByTestId("return-location")).toHaveText("Boston Returns");
  await expect(page.getByTestId("timeline")).toContainText("Moved from Portland Returns to Boston Returns");
  await expect(page.getByTestId("shipment-status")).toHaveText("Label requested");
  await waitForLabel(page);
  await expect(page.getByTestId("shipment-tracking")).not.toHaveText(firstTracking);

  const postOrder = await findOrder(page, shop);
  const own = await submitReturn(page, shop, postOrder, "Post it yourself");
  await openReturn(page, own.number);
  await act(page, "Approve", "Approved");
  await pageHeader(page).getByRole("button", { name: "Move" }).click();
  await choose(page, "New location", "Seattle Returns");
  await page.getByRole("button", { name: "Move return" }).click();
  await expect(page.getByTestId("return-location")).toHaveText("Seattle Returns");

  await expectEmail(page.request, postOrder.email, `Where to post your return ${own.number} has changed`);
  await page.goto(own.statusUrl);
  await expect(page.getByText("Post your parcel to Seattle Returns, 80 Depot Road, Seattle, WA")).toBeVisible();

  await page.goto("/locations");
  await austin.getByRole("button", { name: "Unarchive" }).click();
  await page.getByRole("dialog").getByRole("button", { name: "Unarchive" }).click();
  await expect(austin).toContainText("Active");
});

import { expect, test } from "@playwright/test";
import { act, expectEmail, findOrder, logIn, openReturn, reloadUntilVisible, setShippingScenario, SHOPS, submitReturn, waitForLabel } from "../support";

const shop = SHOPS.harbour;

test.afterAll(async ({ request }) => {
  await setShippingScenario(request, "normal");
});

test("a label the carrier refused shows on the return, and requesting it again gets the label", async ({ page }) => {
  await setShippingScenario(page.request, "carrier_failure");
  await logIn(page, shop);
  const order = await findOrder(page, shop);
  const { number } = await submitReturn(page, shop, order, "Prepaid label");

  await openReturn(page, number);
  await act(page, "Approve", "Approved");
  await expect(page.getByTestId("shipment-status")).toHaveText("Label requested");
  await reloadUntilVisible(page, page.getByRole("button", { name: "Request label again" }));
  await expect(page.getByText("The carrier rejected the label request.").first()).toBeVisible();

  await setShippingScenario(page.request, "normal");
  await page.getByRole("button", { name: "Request label again" }).click();
  await waitForLabel(page);
  await expect(page.getByTestId("shipment-tracking")).toHaveText(/^QP\d+$/);
  await expectEmail(page.request, order.email, `Your prepaid label for return ${number}`);
});

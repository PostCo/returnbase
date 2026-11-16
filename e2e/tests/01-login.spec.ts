import { expect, test } from "@playwright/test";
import { logIn, SHOPS } from "../support";

test("a wrong password is refused", async ({ page }) => {
  await page.goto("/login");
  await page.getByLabel("Email").fill(SHOPS.kopi.email);
  await page.getByLabel("Password").fill("not-the-password");
  await page.getByRole("button", { name: "Log in" }).click();
  await expect(page.getByText("Wrong email or password")).toBeVisible();
});

test("each seeded merchant logs in to their own shop and logs out", async ({ page }) => {
  for (const shop of Object.values(SHOPS)) {
    await logIn(page, shop);
    await expect(page.getByRole("heading", { name: "Manage returns" })).toBeVisible();
    await page.getByRole("button", { name: "Log out" }).click();
    await expect(page.getByRole("button", { name: "Log in" })).toBeVisible();
  }
});

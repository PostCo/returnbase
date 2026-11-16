import { defineConfig, devices } from "@playwright/test";

// The specs share one seeded database and build on each other in file order, so they run one at a time.
// bin/e2e resets the database, the fake vendors and Mailpit before each run.
export default defineConfig({
  testDir: "./tests",
  workers: 1,
  fullyParallel: false,
  timeout: 90_000,
  expect: { timeout: 10_000 },
  reporter: [["list"], ["html", { open: "never" }]],
  use: {
    baseURL: process.env.BASE_URL ?? "http://localhost:5180",
    screenshot: "on",
    trace: "retain-on-failure",
  },
  projects: [{ name: "chromium", use: { ...devices["Desktop Chrome"] } }],
});

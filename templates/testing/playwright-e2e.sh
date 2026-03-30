#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$0")/../.." && pwd)/lib/utils.sh"

parse_args "my-playwright-e2e" "$@"
create_project_dir

# --- package.json ---
write_package_json '{
  "name": "'"$PROJECT_NAME"'",
  "version": "0.1.0",
  "private": true,
  "type": "module",
  "scripts": {
    "test": "playwright test",
    "test:ui": "playwright test --ui",
    "test:headed": "playwright test --headed",
    "test:debug": "playwright test --debug",
    "report": "playwright show-report",
    "codegen": "playwright codegen"
  },
  "devDependencies": {
    "@playwright/test": "^1.51.0",
    "@types/node": "^22.14.0",
    "typescript": "^5.8.3"
  }
}'

# --- tsconfig.json ---
write_tsconfig '{
  "compilerOptions": {
    "target": "ES2022",
    "module": "ESNext",
    "moduleResolution": "bundler",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "rootDir": ".",
    "baseUrl": ".",
    "paths": {
      "@/*": ["./*"]
    }
  },
  "include": ["**/*.ts"],
  "exclude": ["node_modules"]
}'

# --- playwright.config.ts ---
write_file "playwright.config.ts" 'import { defineConfig, devices } from "@playwright/test";

export default defineConfig({
  testDir: "./tests",
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,
  reporter: [
    ["html"],
    ["list"],
    ...(process.env.CI ? [["github" as const]] : []),
  ],
  use: {
    baseURL: process.env.BASE_URL || "http://localhost:3000",
    trace: "on-first-retry",
    screenshot: "only-on-failure",
    video: "retain-on-failure",
  },
  projects: [
    {
      name: "setup",
      testMatch: /.*\.setup\.ts/,
    },
    {
      name: "chromium",
      use: {
        ...devices["Desktop Chrome"],
        storageState: "tests/.auth/user.json",
      },
      dependencies: ["setup"],
    },
    {
      name: "firefox",
      use: {
        ...devices["Desktop Firefox"],
        storageState: "tests/.auth/user.json",
      },
      dependencies: ["setup"],
    },
    {
      name: "webkit",
      use: {
        ...devices["Desktop Safari"],
        storageState: "tests/.auth/user.json",
      },
      dependencies: ["setup"],
    },
    {
      name: "mobile-chrome",
      use: {
        ...devices["Pixel 5"],
        storageState: "tests/.auth/user.json",
      },
      dependencies: ["setup"],
    },
  ],
  /* Uncomment to run your local dev server before tests */
  // webServer: {
  //   command: "npm run dev",
  //   url: "http://localhost:3000",
  //   reuseExistingServer: !process.env.CI,
  // },
});'

# --- tests/example.spec.ts ---
write_file "tests/example.spec.ts" 'import { test, expect } from "@playwright/test";

test.describe("Homepage", () => {
  test("should display the title", async ({ page }) => {
    await page.goto("/");
    await expect(page).toHaveTitle(/.+/);
  });

  test("should have a visible heading", async ({ page }) => {
    await page.goto("/");
    const heading = page.getByRole("heading", { level: 1 });
    await expect(heading).toBeVisible();
  });

  test("should navigate to about page", async ({ page }) => {
    await page.goto("/");
    await page.getByRole("link", { name: /about/i }).click();
    await expect(page).toHaveURL(/.*about/);
  });

  test("should be responsive", async ({ page }) => {
    await page.setViewportSize({ width: 375, height: 667 });
    await page.goto("/");
    await expect(page.locator("body")).toBeVisible();
  });
});

test.describe("Accessibility", () => {
  test("should not have any automatically detectable accessibility issues", async ({
    page,
  }) => {
    await page.goto("/");

    // Check for basic accessibility
    const images = page.locator("img");
    const count = await images.count();
    for (let i = 0; i < count; i++) {
      await expect(images.nth(i)).toHaveAttribute("alt", /.*/);
    }
  });
});'

# --- tests/auth.spec.ts ---
write_file "tests/auth.spec.ts" 'import { test, expect } from "@playwright/test";

test.describe("Authentication", () => {
  test("should show login page", async ({ page }) => {
    await page.goto("/login");
    await expect(page.getByRole("heading", { name: /log in|sign in/i })).toBeVisible();
  });

  test("should show validation errors for empty form", async ({ page }) => {
    await page.goto("/login");
    await page.getByRole("button", { name: /log in|sign in|submit/i }).click();
    // Check for validation messages
    const alerts = page.getByRole("alert");
    await expect(alerts.first()).toBeVisible();
  });

  test("should login with valid credentials", async ({ page }) => {
    await page.goto("/login");
    await page.getByLabel(/email/i).fill("test@example.com");
    await page.getByLabel(/password/i).fill("password123");
    await page.getByRole("button", { name: /log in|sign in|submit/i }).click();
    // Should redirect to dashboard
    await expect(page).toHaveURL(/.*dashboard/);
  });

  test("should show error for invalid credentials", async ({ page }) => {
    await page.goto("/login");
    await page.getByLabel(/email/i).fill("invalid@example.com");
    await page.getByLabel(/password/i).fill("wrongpassword");
    await page.getByRole("button", { name: /log in|sign in|submit/i }).click();
    await expect(page.getByText(/invalid|incorrect|error/i)).toBeVisible();
  });

  test("should logout successfully", async ({ page }) => {
    await page.goto("/dashboard");
    await page.getByRole("button", { name: /log out|sign out/i }).click();
    await expect(page).toHaveURL(/.*login/);
  });
});'

# --- tests/auth.setup.ts ---
write_file "tests/auth.setup.ts" 'import { test as setup, expect } from "@playwright/test";
import path from "node:path";

const authFile = path.join(import.meta.dirname, ".auth/user.json");

setup("authenticate", async ({ page }) => {
  // Navigate to login page
  await page.goto("/login");

  // Fill in credentials
  await page.getByLabel(/email/i).fill("test@example.com");
  await page.getByLabel(/password/i).fill("password123");
  await page.getByRole("button", { name: /log in|sign in|submit/i }).click();

  // Wait for redirect after login
  await page.waitForURL("**/dashboard");
  await expect(page.getByRole("heading", { name: /dashboard/i })).toBeVisible();

  // Save authentication state
  await page.context().storageState({ path: authFile });
});'

# --- tests/fixtures/test-fixtures.ts ---
write_file "tests/fixtures/test-fixtures.ts" 'import { test as base, expect } from "@playwright/test";

// Define custom fixtures
type TestFixtures = {
  todoPage: TodoPage;
};

class TodoPage {
  constructor(private readonly page: import("@playwright/test").Page) {}

  async goto() {
    await this.page.goto("/todos");
  }

  async addTodo(text: string) {
    await this.page.getByPlaceholder(/add/i).fill(text);
    await this.page.getByPlaceholder(/add/i).press("Enter");
  }

  async toggleTodo(text: string) {
    await this.page.getByText(text).getByRole("checkbox").click();
  }

  async deleteTodo(text: string) {
    const item = this.page.getByText(text);
    await item.hover();
    await item.getByRole("button", { name: /delete|remove/i }).click();
  }

  async expectTodoCount(count: number) {
    await expect(this.page.getByTestId("todo-item")).toHaveCount(count);
  }

  async expectTodoVisible(text: string) {
    await expect(this.page.getByText(text)).toBeVisible();
  }
}

export const test = base.extend<TestFixtures>({
  todoPage: async ({ page }, use) => {
    const todoPage = new TodoPage(page);
    await use(todoPage);
  },
});

export { expect };'

# --- tests/.auth/.gitkeep ---
write_file "tests/.auth/.gitkeep" ""

# --- .github/workflows/playwright.yml ---
write_file ".github/workflows/playwright.yml" 'name: Playwright Tests

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  test:
    timeout-minutes: 60
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-node@v4
        with:
          node-version: 22
          cache: npm

      - name: Install dependencies
        run: npm ci

      - name: Install Playwright Browsers
        run: npx playwright install --with-deps

      - name: Run Playwright tests
        run: npx playwright test
        env:
          BASE_URL: http://localhost:3000

      - uses: actions/upload-artifact@v4
        if: ${{ !cancelled() }}
        with:
          name: playwright-report
          path: playwright-report/
          retention-days: 30'

init_git
write_gitignore "playwright-report/" "test-results/" "tests/.auth/user.json" "blob-report/"
write_editorconfig
write_nvmrc

finish "npm install" "npx playwright install"

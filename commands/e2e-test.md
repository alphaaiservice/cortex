---
description: "Generate end-to-end tests using Playwright (web) and Detox (mobile). Covers user flows, visual regression, and cross-browser testing. Usage: /e2e-test [flow-name|--all] [--visual]"
---

# End-to-End Test Generation

Generate comprehensive end-to-end tests for: **$ARGUMENTS**

Parse $ARGUMENTS for:
- A specific flow name (e.g., `auth`, `payment`, `crud`, `search`, `settings`, `admin`, `profile`, `responsive`)
- `--all` flag: generate E2E tests for every discovered user flow
- `--visual` flag: include visual regression testing with baseline screenshots
- If no arguments provided, default to `--all`

---

## Step 1: Analyze Application Flows

### 1.1 Detect Project Type and Structure

```bash
# Detect if this is a web project (Next.js / React)
ls -la package.json 2>/dev/null
ls -la next.config.* 2>/dev/null
ls -la app/ 2>/dev/null
ls -la src/app/ 2>/dev/null
ls -la pages/ 2>/dev/null

# Detect if this is a mobile project (React Native / Expo)
ls -la app.json 2>/dev/null
ls -la expo-env.d.ts 2>/dev/null
ls -la metro.config.* 2>/dev/null
ls -la android/ 2>/dev/null
ls -la ios/ 2>/dev/null
```

### 1.2 Scan Web Routes (Next.js App Router)

Use Glob to find all route files:
- `**/app/**/page.tsx` — Next.js 13+ App Router pages
- `**/app/**/page.jsx` — JSX variant
- `**/pages/**/*.tsx` — Pages Router (legacy)
- `**/pages/**/*.jsx` — JSX variant

For each discovered page file:
1. Read the file to understand the component
2. Extract the route path from the file system path (e.g., `app/dashboard/settings/page.tsx` maps to `/dashboard/settings`)
3. Identify dynamic route segments (e.g., `[id]`, `[slug]`, `[...catchAll]`)
4. Detect route groups `(group-name)` and exclude them from the URL path
5. Identify layout files (`layout.tsx`) that wrap multiple routes
6. Detect loading states (`loading.tsx`) and error boundaries (`error.tsx`)
7. Detect middleware files (`middleware.ts`) that may redirect or protect routes
8. Identify parallel routes and intercepting routes if present

### 1.3 Scan React Native Screens (if mobile project exists)

Use Glob to find all screen files:
- `**/screens/**/*.tsx`
- `**/screens/**/*.jsx`
- `**/app/**/_layout.tsx` (Expo Router)
- `**/app/**/index.tsx` (Expo Router)

For each discovered screen:
1. Read the screen component
2. Extract the screen name and navigation path
3. Identify navigation stack structure (Stack, Tab, Drawer)
4. Map deep linking routes if configured

### 1.4 Identify User Flows

Analyze the discovered routes and screens to identify these flow categories:

| Flow Category | What to Look For |
|---------------|------------------|
| **Auth Flow** | Login page, register page, forgot password, OTP verification, social login buttons, logout actions |
| **CRUD Operations** | Forms with create/edit actions, list pages with delete buttons, detail/view pages |
| **Payment Flow** | Checkout pages, subscription pages, pricing tables, payment form inputs, success/failure pages |
| **Search Flow** | Search inputs, filter dropdowns, sort controls, pagination components, empty states |
| **Profile Flow** | Profile view page, edit profile form, avatar upload, password change |
| **Settings Flow** | Settings page, theme toggle, language selector, notification preferences, 2FA setup |
| **Admin Flow** | Admin routes, user management tables, dashboard analytics, content moderation |
| **Navigation Flow** | Sidebar nav, header nav, breadcrumbs, back buttons, tab switches |
| **Onboarding Flow** | Welcome screens, stepper/wizard components, tutorial overlays |
| **Notification Flow** | Notification bell, notification list, mark as read, push permission dialogs |

### 1.5 Map Form Inputs and Validations

Use Grep to scan for form-related patterns:
- `<form`, `<Form`, `useForm`, `formik`, `react-hook-form`
- `<input`, `<Input`, `<textarea`, `<select`, `<Select`
- `required`, `minLength`, `maxLength`, `pattern`, `validate`
- `type="email"`, `type="password"`, `type="tel"`, `type="file"`
- `onSubmit`, `handleSubmit`, `action=`
- Zod schemas, Yup schemas, or other validation libraries

Record each form's:
- Input field names, types, and validation rules
- Required vs optional fields
- Error messages for invalid inputs
- Submit button selector
- Success/failure feedback mechanisms

### 1.6 Identify API Endpoints

Use Grep to find API calls:
- `fetch(`, `axios.`, `useSWR`, `useQuery`, `trpc.`
- `api/` route handlers in Next.js (`app/api/**/route.ts`)
- Environment variables for base URLs (`NEXT_PUBLIC_API_URL`, `API_BASE_URL`)

Map each endpoint to its corresponding UI flow for integration testing.

---

## Step 2: Setup Playwright (Web)

### 2.1 Check Existing Installation

```bash
# Check if Playwright is already installed
npx playwright --version 2>/dev/null
ls -la playwright.config.* 2>/dev/null
```

### 2.2 Install Playwright (if not present)

```bash
# Install Playwright as dev dependency
npm install -D @playwright/test @axe-core/playwright

# Install browsers
npx playwright install --with-deps chromium firefox webkit
```

### 2.3 Create Playwright Configuration

Create `playwright.config.ts` at project root with the following configuration:

```typescript
import { defineConfig, devices } from '@playwright/test';
import path from 'path';

/**
 * Playwright E2E Test Configuration
 * Generated by Cortex — /e2e-test command
 *
 * Browsers: Chromium, Firefox, WebKit
 * Viewports: Desktop (1280x720), Tablet (768x1024), Mobile (375x667)
 * Features: Screenshots on failure, video on failure, trace viewer, HTML + JUnit reports
 */

const BASE_URL = process.env.PLAYWRIGHT_BASE_URL || process.env.NEXT_PUBLIC_BASE_URL || 'http://localhost:3000';

export default defineConfig({
  /* Test directory */
  testDir: './tests/e2e',

  /* Global setup file — seeds database, creates test users */
  globalSetup: './tests/e2e/global-setup.ts',

  /* Global teardown file — cleans up test data */
  globalTeardown: './tests/e2e/global-teardown.ts',

  /* Maximum time one test can run */
  timeout: 60_000,

  /* Maximum time expect() assertions can take */
  expect: {
    timeout: 10_000,
    /* Visual comparison thresholds */
    toHaveScreenshot: {
      maxDiffPixelRatio: 0.01,
      threshold: 0.2,
    },
    toMatchSnapshot: {
      maxDiffPixelRatio: 0.01,
    },
  },

  /* Fail the build on CI if you accidentally left test.only in the source code */
  forbidOnly: !!process.env.CI,

  /* Retry on CI only */
  retries: process.env.CI ? 2 : 0,

  /* Limit parallel workers on CI to avoid resource issues */
  workers: process.env.CI ? 2 : undefined,

  /* Reporters: HTML for local viewing, JUnit for CI integration */
  reporter: [
    ['html', { open: 'never', outputFolder: 'playwright-report' }],
    ['junit', { outputFile: 'test-results/junit-results.xml' }],
    ['list'],
  ],

  /* Shared settings for all projects */
  use: {
    /* Base URL for navigation actions like page.goto('/') */
    baseURL: BASE_URL,

    /* Capture screenshot only on failure */
    screenshot: 'only-on-failure',

    /* Record video only on failure */
    video: 'retain-on-failure',

    /* Collect trace on first retry */
    trace: 'on-first-retry',

    /* Maximum time each action (click, fill, etc.) can take */
    actionTimeout: 15_000,

    /* Maximum time for navigation */
    navigationTimeout: 30_000,

    /* Accept downloads */
    acceptDownloads: true,

    /* Extra HTTP headers */
    extraHTTPHeaders: {
      'Accept-Language': 'en-US,en;q=0.9',
    },
  },

  /* Configure browser projects for cross-browser + cross-viewport testing */
  projects: [
    /* ============================================= */
    /*  SETUP PROJECT — runs auth setup first        */
    /* ============================================= */
    {
      name: 'setup',
      testMatch: /.*\.setup\.ts/,
    },

    /* ============================================= */
    /*  DESKTOP BROWSERS (1280x720)                  */
    /* ============================================= */
    {
      name: 'chromium-desktop',
      use: {
        ...devices['Desktop Chrome'],
        viewport: { width: 1280, height: 720 },
        storageState: path.join(__dirname, 'tests/e2e/.auth/user.json'),
      },
      dependencies: ['setup'],
    },
    {
      name: 'firefox-desktop',
      use: {
        ...devices['Desktop Firefox'],
        viewport: { width: 1280, height: 720 },
        storageState: path.join(__dirname, 'tests/e2e/.auth/user.json'),
      },
      dependencies: ['setup'],
    },
    {
      name: 'webkit-desktop',
      use: {
        ...devices['Desktop Safari'],
        viewport: { width: 1280, height: 720 },
        storageState: path.join(__dirname, 'tests/e2e/.auth/user.json'),
      },
      dependencies: ['setup'],
    },

    /* ============================================= */
    /*  TABLET VIEWPORT (768x1024)                   */
    /* ============================================= */
    {
      name: 'chromium-tablet',
      use: {
        ...devices['iPad (gen 7)'],
        storageState: path.join(__dirname, 'tests/e2e/.auth/user.json'),
      },
      dependencies: ['setup'],
    },

    /* ============================================= */
    /*  MOBILE VIEWPORT (375x667)                    */
    /* ============================================= */
    {
      name: 'chromium-mobile',
      use: {
        ...devices['iPhone 13'],
        storageState: path.join(__dirname, 'tests/e2e/.auth/user.json'),
      },
      dependencies: ['setup'],
    },
    {
      name: 'webkit-mobile',
      use: {
        ...devices['iPhone 13'],
        storageState: path.join(__dirname, 'tests/e2e/.auth/user.json'),
      },
      dependencies: ['setup'],
    },
  ],

  /* Run local dev server before starting the tests */
  webServer: {
    command: process.env.CI ? 'npm run start' : 'npm run dev',
    url: BASE_URL,
    reuseExistingServer: !process.env.CI,
    timeout: 120_000,
    stdout: 'pipe',
    stderr: 'pipe',
  },
});
```

### 2.4 Add Scripts to package.json

```bash
# Add E2E test scripts to package.json
npm pkg set scripts.test:e2e="npx playwright test"
npm pkg set scripts.test:e2e:ui="npx playwright test --ui"
npm pkg set scripts.test:e2e:headed="npx playwright test --headed"
npm pkg set scripts.test:e2e:debug="npx playwright test --debug"
npm pkg set scripts.test:e2e:report="npx playwright show-report"
npm pkg set scripts.test:e2e:chromium="npx playwright test --project=chromium-desktop"
npm pkg set scripts.test:e2e:firefox="npx playwright test --project=firefox-desktop"
npm pkg set scripts.test:e2e:webkit="npx playwright test --project=webkit-desktop"
npm pkg set scripts.test:e2e:mobile="npx playwright test --project=chromium-mobile"
npm pkg set scripts.test:e2e:visual="npx playwright test tests/e2e/visual/"
```

### 2.5 Create .gitignore Entries

Append to `.gitignore` if not already present:

```
# Playwright
/test-results/
/playwright-report/
/blob-report/
/playwright/.cache/
tests/e2e/.auth/
```

---

## Step 3: Generate Web E2E Tests

Create the following directory structure under `tests/e2e/`:

```
tests/e2e/
  fixtures/
    auth.fixture.ts
    data.fixture.ts
    page-objects/
      base.page.ts
      login.page.ts
      register.page.ts
      dashboard.page.ts
      profile.page.ts
      settings.page.ts
      search.page.ts
      admin.page.ts
      (additional page objects based on discovered routes)
  flows/
    auth.spec.ts
    profile.spec.ts
    crud.spec.ts
    search.spec.ts
    payment.spec.ts
    admin.spec.ts
    settings.spec.ts
    responsive.spec.ts
    navigation.spec.ts
    error-handling.spec.ts
    (additional spec files based on discovered flows)
  visual/
    screenshots.spec.ts
    snapshots/
      (empty — baselines captured on first run)
  auth.setup.ts
  global-setup.ts
  global-teardown.ts
  .auth/
    (empty — storage state saved here during auth setup)
```

### 3.1 Create Base Page Object

Create `tests/e2e/fixtures/page-objects/base.page.ts`:

```typescript
import { type Page, type Locator, expect } from '@playwright/test';

/**
 * BasePage — Abstract base class for all Page Objects.
 *
 * Provides common navigation, waiting, and assertion helpers.
 * All page objects extend this class to inherit shared behavior.
 *
 * Pattern: Page Object Model (POM)
 * - Encapsulates page-specific selectors and actions
 * - Tests never directly interact with selectors
 * - Changes to UI only require updates in one place
 */
export abstract class BasePage {
  readonly page: Page;

  constructor(page: Page) {
    this.page = page;
  }

  /** Navigate to this page's URL */
  abstract goto(): Promise<void>;

  /** Assert that we are on this page (check URL and/or key element) */
  abstract isVisible(): Promise<void>;

  /* ============================= */
  /*  NAVIGATION HELPERS           */
  /* ============================= */

  /** Navigate to any path relative to baseURL */
  async navigateTo(path: string): Promise<void> {
    await this.page.goto(path, { waitUntil: 'networkidle' });
  }

  /** Wait for navigation to complete after clicking a link/button */
  async waitForNavigation(): Promise<void> {
    await this.page.waitForLoadState('networkidle');
  }

  /** Get the current URL path (without base URL) */
  getCurrentPath(): string {
    const url = new URL(this.page.url());
    return url.pathname;
  }

  /* ============================= */
  /*  WAITING HELPERS              */
  /* ============================= */

  /** Wait for an element to be visible on the page */
  async waitForElement(selector: string, timeout = 10_000): Promise<Locator> {
    const locator = this.page.locator(selector);
    await locator.waitFor({ state: 'visible', timeout });
    return locator;
  }

  /** Wait for loading spinners/skeletons to disappear */
  async waitForLoadingToComplete(): Promise<void> {
    // Wait for common loading indicators to disappear
    const loadingSelectors = [
      '[data-testid="loading"]',
      '[data-testid="spinner"]',
      '[data-testid="skeleton"]',
      '.loading',
      '.spinner',
      '[role="progressbar"]',
      '[aria-busy="true"]',
    ];

    for (const selector of loadingSelectors) {
      const locator = this.page.locator(selector);
      if (await locator.count() > 0) {
        await locator.first().waitFor({ state: 'hidden', timeout: 15_000 }).catch(() => {
          // Ignore — some loading indicators may not be present
        });
      }
    }
  }

  /** Wait for a specific API response */
  async waitForApiResponse(urlPattern: string | RegExp, status = 200): Promise<void> {
    await this.page.waitForResponse(
      (response) =>
        (typeof urlPattern === 'string'
          ? response.url().includes(urlPattern)
          : urlPattern.test(response.url())) && response.status() === status,
    );
  }

  /* ============================= */
  /*  FORM HELPERS                 */
  /* ============================= */

  /** Fill a form field by label text */
  async fillByLabel(label: string, value: string): Promise<void> {
    await this.page.getByLabel(label).fill(value);
  }

  /** Fill a form field by placeholder text */
  async fillByPlaceholder(placeholder: string, value: string): Promise<void> {
    await this.page.getByPlaceholder(placeholder).fill(value);
  }

  /** Fill a form field by test ID */
  async fillByTestId(testId: string, value: string): Promise<void> {
    await this.page.getByTestId(testId).fill(value);
  }

  /** Click a button by its visible text */
  async clickButton(text: string): Promise<void> {
    await this.page.getByRole('button', { name: text }).click();
  }

  /** Click a link by its visible text */
  async clickLink(text: string): Promise<void> {
    await this.page.getByRole('link', { name: text }).click();
  }

  /** Select an option from a dropdown by label */
  async selectOption(label: string, value: string): Promise<void> {
    await this.page.getByLabel(label).selectOption(value);
  }

  /** Toggle a checkbox by label */
  async toggleCheckbox(label: string): Promise<void> {
    await this.page.getByLabel(label).check();
  }

  /** Upload a file to a file input */
  async uploadFile(selector: string, filePath: string): Promise<void> {
    await this.page.locator(selector).setInputFiles(filePath);
  }

  /* ============================= */
  /*  ASSERTION HELPERS            */
  /* ============================= */

  /** Assert a toast/notification message appears */
  async expectToast(message: string): Promise<void> {
    const toast = this.page.locator('[role="alert"], [role="status"], .toast, .notification');
    await expect(toast.filter({ hasText: message })).toBeVisible({ timeout: 10_000 });
  }

  /** Assert the page title */
  async expectTitle(title: string | RegExp): Promise<void> {
    await expect(this.page).toHaveTitle(title);
  }

  /** Assert the current URL */
  async expectUrl(url: string | RegExp): Promise<void> {
    await expect(this.page).toHaveURL(url);
  }

  /** Assert an element contains specific text */
  async expectText(selector: string, text: string | RegExp): Promise<void> {
    await expect(this.page.locator(selector)).toContainText(text);
  }

  /** Assert an element is visible */
  async expectVisible(selector: string): Promise<void> {
    await expect(this.page.locator(selector)).toBeVisible();
  }

  /** Assert an element is NOT visible */
  async expectHidden(selector: string): Promise<void> {
    await expect(this.page.locator(selector)).toBeHidden();
  }

  /* ============================= */
  /*  ACCESSIBILITY HELPERS        */
  /* ============================= */

  /** Run axe-core accessibility scan on the current page */
  async checkAccessibility(
    disableRules: string[] = [],
    includeSelector?: string,
  ): Promise<void> {
    // Accessibility check is performed in individual test files
    // using @axe-core/playwright — this helper documents the pattern
    // See auth.spec.ts for usage example with AxeBuilder
  }

  /* ============================= */
  /*  SCREENSHOT HELPERS           */
  /* ============================= */

  /** Take a full-page screenshot */
  async takeScreenshot(name: string): Promise<Buffer> {
    return await this.page.screenshot({
      fullPage: true,
      path: `tests/e2e/visual/snapshots/${name}.png`,
    });
  }

  /** Take a screenshot of a specific element */
  async takeElementScreenshot(selector: string, name: string): Promise<Buffer> {
    return await this.page.locator(selector).screenshot({
      path: `tests/e2e/visual/snapshots/${name}.png`,
    });
  }

  /* ============================= */
  /*  UTILITY HELPERS              */
  /* ============================= */

  /** Get text content of an element */
  async getTextContent(selector: string): Promise<string | null> {
    return await this.page.locator(selector).textContent();
  }

  /** Get the count of matching elements */
  async getElementCount(selector: string): Promise<number> {
    return await this.page.locator(selector).count();
  }

  /** Check if an element exists in the DOM (may or may not be visible) */
  async elementExists(selector: string): Promise<boolean> {
    return (await this.page.locator(selector).count()) > 0;
  }

  /** Scroll to the bottom of the page */
  async scrollToBottom(): Promise<void> {
    await this.page.evaluate(() => window.scrollTo(0, document.body.scrollHeight));
    await this.page.waitForTimeout(500); // Allow lazy-loaded content to render
  }

  /** Scroll to a specific element */
  async scrollToElement(selector: string): Promise<void> {
    await this.page.locator(selector).scrollIntoViewIfNeeded();
  }

  /** Press a keyboard key */
  async pressKey(key: string): Promise<void> {
    await this.page.keyboard.press(key);
  }

  /** Dismiss any visible dialog/modal */
  async dismissDialog(): Promise<void> {
    this.page.on('dialog', async (dialog) => {
      await dialog.dismiss();
    });
  }

  /** Accept any visible dialog/modal */
  async acceptDialog(): Promise<void> {
    this.page.on('dialog', async (dialog) => {
      await dialog.accept();
    });
  }
}
```

### 3.2 Create Auth Fixture

Create `tests/e2e/fixtures/auth.fixture.ts`:

```typescript
import { test as base, expect } from '@playwright/test';

/**
 * Auth Fixture — Extends Playwright's base test with authentication helpers.
 *
 * Provides:
 * - Authenticated user context (logged in before each test)
 * - Admin user context (admin privileges)
 * - Unauthenticated context (explicitly logged out)
 * - Login/logout helper methods
 */

// Test user credentials (from environment or defaults for local dev)
export const TEST_USER = {
  email: process.env.TEST_USER_EMAIL || 'testuser@example.com',
  password: process.env.TEST_USER_PASSWORD || 'TestPassword123!',
  name: process.env.TEST_USER_NAME || 'Test User',
};

export const TEST_ADMIN = {
  email: process.env.TEST_ADMIN_EMAIL || 'admin@example.com',
  password: process.env.TEST_ADMIN_PASSWORD || 'AdminPassword123!',
  name: process.env.TEST_ADMIN_NAME || 'Admin User',
};

type AuthFixtures = {
  /** Helper to log in as the test user */
  loginAsUser: () => Promise<void>;
  /** Helper to log in as admin */
  loginAsAdmin: () => Promise<void>;
  /** Helper to log out */
  logout: () => Promise<void>;
  /** Helper to register a new user */
  registerUser: (email: string, password: string, name: string) => Promise<void>;
};

export const test = base.extend<AuthFixtures>({
  loginAsUser: async ({ page }, use) => {
    const loginAsUser = async () => {
      await page.goto('/login');
      await page.getByLabel(/email/i).fill(TEST_USER.email);
      await page.getByLabel(/password/i).fill(TEST_USER.password);
      await page.getByRole('button', { name: /sign in|log in|login/i }).click();
      // Wait for redirect after successful login
      await page.waitForURL(/\/(dashboard|home|\/)/, { timeout: 15_000 });
      await page.waitForLoadState('networkidle');
    };
    await use(loginAsUser);
  },

  loginAsAdmin: async ({ page }, use) => {
    const loginAsAdmin = async () => {
      await page.goto('/login');
      await page.getByLabel(/email/i).fill(TEST_ADMIN.email);
      await page.getByLabel(/password/i).fill(TEST_ADMIN.password);
      await page.getByRole('button', { name: /sign in|log in|login/i }).click();
      await page.waitForURL(/\/(admin|dashboard)/, { timeout: 15_000 });
      await page.waitForLoadState('networkidle');
    };
    await use(loginAsAdmin);
  },

  logout: async ({ page }, use) => {
    const logout = async () => {
      // Try common logout patterns
      const logoutButton = page.getByRole('button', { name: /log\s?out|sign\s?out/i });
      const logoutLink = page.getByRole('link', { name: /log\s?out|sign\s?out/i });
      const userMenu = page.locator('[data-testid="user-menu"], [aria-label="User menu"]');

      // Some apps have logout behind a user menu
      if (await userMenu.count() > 0) {
        await userMenu.click();
      }

      if (await logoutButton.count() > 0) {
        await logoutButton.click();
      } else if (await logoutLink.count() > 0) {
        await logoutLink.click();
      } else {
        // Fallback: navigate to logout endpoint
        await page.goto('/api/auth/logout');
      }

      await page.waitForURL(/\/(login|signin|\/)/, { timeout: 10_000 });
    };
    await use(logout);
  },

  registerUser: async ({ page }, use) => {
    const registerUser = async (email: string, password: string, name: string) => {
      await page.goto('/register');
      await page.getByLabel(/name|full name/i).fill(name);
      await page.getByLabel(/email/i).fill(email);
      await page.getByLabel(/^password$/i).fill(password);

      // Fill confirm password if it exists
      const confirmPassword = page.getByLabel(/confirm password|re-enter password/i);
      if (await confirmPassword.count() > 0) {
        await confirmPassword.fill(password);
      }

      // Accept terms if checkbox exists
      const termsCheckbox = page.getByLabel(/terms|agree/i);
      if (await termsCheckbox.count() > 0) {
        await termsCheckbox.check();
      }

      await page.getByRole('button', { name: /sign up|register|create account/i }).click();
      await page.waitForLoadState('networkidle');
    };
    await use(registerUser);
  },
});

export { expect };
```

### 3.3 Create Data Fixture (Test Data Factory)

Create `tests/e2e/fixtures/data.fixture.ts`:

```typescript
import { randomUUID } from 'crypto';

/**
 * Test Data Factory — Generates unique, realistic test data for E2E tests.
 *
 * Every factory function produces unique values using UUIDs to prevent
 * test data collisions when running tests in parallel.
 */

/** Generate a unique email address */
export function uniqueEmail(prefix = 'e2etest'): string {
  const id = randomUUID().slice(0, 8);
  return `${prefix}+${id}@test.example.com`;
}

/** Generate a unique username */
export function uniqueUsername(prefix = 'user'): string {
  const id = randomUUID().slice(0, 8);
  return `${prefix}_${id}`;
}

/** Generate a unique name */
export function uniqueName(): string {
  const firstNames = ['Alice', 'Bob', 'Charlie', 'Diana', 'Eve', 'Frank', 'Grace', 'Hank'];
  const lastNames = ['Smith', 'Johnson', 'Williams', 'Brown', 'Jones', 'Garcia', 'Miller'];
  const first = firstNames[Math.floor(Math.random() * firstNames.length)];
  const last = lastNames[Math.floor(Math.random() * lastNames.length)];
  return `${first} ${last}`;
}

/** Generate test user data */
export function createTestUser(overrides: Partial<TestUser> = {}): TestUser {
  return {
    name: uniqueName(),
    email: uniqueEmail(),
    password: 'SecurePass123!',
    ...overrides,
  };
}

/** Generate test item data (for CRUD operations) */
export function createTestItem(overrides: Partial<TestItem> = {}): TestItem {
  const id = randomUUID().slice(0, 8);
  return {
    title: `Test Item ${id}`,
    description: `This is a test item created for E2E testing. ID: ${id}`,
    category: 'testing',
    tags: ['e2e', 'automated'],
    ...overrides,
  };
}

/** Generate test address data */
export function createTestAddress(overrides: Partial<TestAddress> = {}): TestAddress {
  return {
    street: '123 Test Street',
    city: 'Test City',
    state: 'TS',
    zipCode: '12345',
    country: 'US',
    ...overrides,
  };
}

/** Generate test payment data (use Stripe test card numbers) */
export function createTestPayment(overrides: Partial<TestPayment> = {}): TestPayment {
  return {
    cardNumber: '4242424242424242',
    expiryMonth: '12',
    expiryYear: '2030',
    cvc: '123',
    nameOnCard: 'Test User',
    ...overrides,
  };
}

/** Generate a random string of specified length */
export function randomString(length: number): string {
  const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  let result = '';
  for (let i = 0; i < length; i++) {
    result += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return result;
}

/** Generate a random integer between min and max (inclusive) */
export function randomInt(min: number, max: number): number {
  return Math.floor(Math.random() * (max - min + 1)) + min;
}

/* ============================= */
/*  TYPE DEFINITIONS             */
/* ============================= */

export interface TestUser {
  name: string;
  email: string;
  password: string;
}

export interface TestItem {
  title: string;
  description: string;
  category: string;
  tags: string[];
}

export interface TestAddress {
  street: string;
  city: string;
  state: string;
  zipCode: string;
  country: string;
}

export interface TestPayment {
  cardNumber: string;
  expiryMonth: string;
  expiryYear: string;
  cvc: string;
  nameOnCard: string;
}
```

### 3.4 Create Auth Setup File

Create `tests/e2e/auth.setup.ts`:

```typescript
import { test as setup, expect } from '@playwright/test';
import path from 'path';

const authFile = path.join(__dirname, '.auth/user.json');

/**
 * Auth Setup — Runs once before all test projects.
 *
 * Logs in as the test user and saves the authenticated browser state
 * (cookies, localStorage) to a JSON file. All subsequent test projects
 * load this state to skip the login flow.
 */
setup('authenticate as test user', async ({ page }) => {
  const email = process.env.TEST_USER_EMAIL || 'testuser@example.com';
  const password = process.env.TEST_USER_PASSWORD || 'TestPassword123!';

  // Navigate to login page
  await page.goto('/login');

  // Fill in credentials
  await page.getByLabel(/email/i).fill(email);
  await page.getByLabel(/password/i).fill(password);

  // Submit login form
  await page.getByRole('button', { name: /sign in|log in|login/i }).click();

  // Wait for successful login — adjust URL pattern to match your app
  await page.waitForURL(/\/(dashboard|home|\/)/, { timeout: 15_000 });

  // Verify we are authenticated
  await page.waitForLoadState('networkidle');

  // Save authentication state
  await page.context().storageState({ path: authFile });
});
```

### 3.5 Create Global Setup and Teardown

Create `tests/e2e/global-setup.ts`:

```typescript
import { FullConfig } from '@playwright/test';

/**
 * Global Setup — Runs once before ALL tests.
 *
 * Responsibilities:
 * - Seed the test database with required data
 * - Create test user accounts
 * - Verify the application is running
 * - Set up any external service mocks
 */
async function globalSetup(config: FullConfig): Promise<void> {
  const baseURL = config.projects[0]?.use?.baseURL || 'http://localhost:3000';

  console.log('[E2E Global Setup] Starting...');
  console.log(`[E2E Global Setup] Base URL: ${baseURL}`);

  // 1. Verify the application is reachable
  try {
    const response = await fetch(baseURL, { method: 'HEAD' });
    if (!response.ok) {
      console.warn(`[E2E Global Setup] Application returned status ${response.status}`);
    }
    console.log('[E2E Global Setup] Application is reachable.');
  } catch (error) {
    console.error('[E2E Global Setup] Application is NOT reachable at', baseURL);
    console.error('[E2E Global Setup] Make sure the dev server is running.');
    throw error;
  }

  // 2. Seed test data via API (if seed endpoint exists)
  try {
    const seedResponse = await fetch(`${baseURL}/api/test/seed`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        users: [
          {
            email: process.env.TEST_USER_EMAIL || 'testuser@example.com',
            password: process.env.TEST_USER_PASSWORD || 'TestPassword123!',
            name: process.env.TEST_USER_NAME || 'Test User',
            role: 'user',
          },
          {
            email: process.env.TEST_ADMIN_EMAIL || 'admin@example.com',
            password: process.env.TEST_ADMIN_PASSWORD || 'AdminPassword123!',
            name: process.env.TEST_ADMIN_NAME || 'Admin User',
            role: 'admin',
          },
        ],
      }),
    });

    if (seedResponse.ok) {
      console.log('[E2E Global Setup] Test data seeded successfully.');
    } else {
      console.warn('[E2E Global Setup] Seed endpoint returned:', seedResponse.status);
      console.warn('[E2E Global Setup] Skipping seed — ensure test users exist manually.');
    }
  } catch {
    console.warn('[E2E Global Setup] No seed endpoint found — skipping database seed.');
    console.warn('[E2E Global Setup] Ensure test user accounts exist before running tests.');
  }

  console.log('[E2E Global Setup] Complete.');
}

export default globalSetup;
```

Create `tests/e2e/global-teardown.ts`:

```typescript
import { FullConfig } from '@playwright/test';

/**
 * Global Teardown — Runs once after ALL tests.
 *
 * Responsibilities:
 * - Clean up test data from the database
 * - Remove temporary files
 * - Reset any external service state
 */
async function globalTeardown(config: FullConfig): Promise<void> {
  const baseURL = config.projects[0]?.use?.baseURL || 'http://localhost:3000';

  console.log('[E2E Global Teardown] Starting...');

  // Clean up test data via API (if cleanup endpoint exists)
  try {
    const cleanupResponse = await fetch(`${baseURL}/api/test/cleanup`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        cleanupPrefix: 'e2etest',
      }),
    });

    if (cleanupResponse.ok) {
      console.log('[E2E Global Teardown] Test data cleaned up successfully.');
    } else {
      console.warn('[E2E Global Teardown] Cleanup endpoint returned:', cleanupResponse.status);
    }
  } catch {
    console.warn('[E2E Global Teardown] No cleanup endpoint found — skipping.');
  }

  console.log('[E2E Global Teardown] Complete.');
}

export default globalTeardown;
```

### 3.6 Generate Page Objects for Discovered Routes

For every route discovered in Step 1.2, create a Page Object class that extends `BasePage`. Each Page Object must:

1. Define selectors for all interactive elements on the page
2. Expose action methods (e.g., `fillLoginForm()`, `submitForm()`, `clickCreateButton()`)
3. Expose assertion methods (e.g., `expectDashboardVisible()`, `expectErrorMessage()`)
4. Never expose raw selectors — all interactions go through methods
5. Use descriptive method names that describe user intent, not implementation

**Example pattern for each Page Object:**

```typescript
import { type Page, expect } from '@playwright/test';
import { BasePage } from './base.page';

export class LoginPage extends BasePage {
  /* Selectors */
  private readonly emailInput = () => this.page.getByLabel(/email/i);
  private readonly passwordInput = () => this.page.getByLabel(/password/i);
  private readonly submitButton = () => this.page.getByRole('button', { name: /sign in|log in/i });
  private readonly errorAlert = () => this.page.locator('[role="alert"]');
  private readonly forgotPasswordLink = () => this.page.getByRole('link', { name: /forgot/i });
  private readonly registerLink = () => this.page.getByRole('link', { name: /sign up|register/i });
  private readonly googleLoginButton = () => this.page.getByRole('button', { name: /google/i });

  async goto(): Promise<void> {
    await this.navigateTo('/login');
    await this.waitForLoadingToComplete();
  }

  async isVisible(): Promise<void> {
    await expect(this.emailInput()).toBeVisible();
    await expect(this.passwordInput()).toBeVisible();
    await expect(this.submitButton()).toBeVisible();
  }

  async login(email: string, password: string): Promise<void> {
    await this.emailInput().fill(email);
    await this.passwordInput().fill(password);
    await this.submitButton().click();
  }

  async expectLoginError(message?: string): Promise<void> {
    await expect(this.errorAlert()).toBeVisible();
    if (message) {
      await expect(this.errorAlert()).toContainText(message);
    }
  }

  async goToForgotPassword(): Promise<void> {
    await this.forgotPasswordLink().click();
    await this.waitForNavigation();
  }

  async goToRegister(): Promise<void> {
    await this.registerLink().click();
    await this.waitForNavigation();
  }
}
```

Generate a Page Object like this for EVERY discovered page/route. Adapt selectors by reading the actual page source code.

### 3.7 Generate Flow Test Specs

For each flow identified in Step 1.4, generate a test spec file. Each spec MUST follow these rules:

**Test Structure Rules:**
1. Use `test.describe()` to group related tests
2. Use `test.beforeEach()` for common setup (navigation, waiting)
3. Use `test.afterEach()` for cleanup (delete created data)
4. NEVER use `page.waitForTimeout()` (arbitrary sleeps) — always use explicit waits
5. Test both happy path AND error/edge cases
6. Use meaningful test names that describe the user's intent
7. Include accessibility checks using `@axe-core/playwright` AxeBuilder
8. Use test data factories from `data.fixture.ts` for unique test data
9. Use Page Objects for all page interactions — never use raw selectors in tests
10. Tag tests with `@smoke`, `@critical`, `@regression` annotations

**Example auth flow spec:**

```typescript
import { test, expect } from '../fixtures/auth.fixture';
import AxeBuilder from '@axe-core/playwright';
import { LoginPage } from '../fixtures/page-objects/login.page';
import { RegisterPage } from '../fixtures/page-objects/register.page';
import { DashboardPage } from '../fixtures/page-objects/dashboard.page';
import { createTestUser } from '../fixtures/data.fixture';

test.describe('Authentication Flow', () => {
  test.describe('Login', () => {
    test('should login with valid credentials and redirect to dashboard @smoke @critical', async ({ page }) => {
      const loginPage = new LoginPage(page);
      const dashboardPage = new DashboardPage(page);

      await loginPage.goto();
      await loginPage.isVisible();
      await loginPage.login('testuser@example.com', 'TestPassword123!');
      await dashboardPage.isVisible();
    });

    test('should show error message with invalid credentials @regression', async ({ page }) => {
      const loginPage = new LoginPage(page);

      await loginPage.goto();
      await loginPage.login('wrong@example.com', 'WrongPassword');
      await loginPage.expectLoginError();
    });

    test('should show validation errors for empty fields @regression', async ({ page }) => {
      const loginPage = new LoginPage(page);

      await loginPage.goto();
      await page.getByRole('button', { name: /sign in|log in/i }).click();
      // Expect validation errors on required fields
      await expect(page.locator(':invalid')).not.toHaveCount(0);
    });

    test('login page should have no accessibility violations @a11y', async ({ page }) => {
      const loginPage = new LoginPage(page);
      await loginPage.goto();

      const results = await new AxeBuilder({ page })
        .withTags(['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa'])
        .analyze();

      expect(results.violations).toEqual([]);
    });
  });

  test.describe('Registration', () => {
    test('should register a new user successfully @smoke @critical', async ({ page, registerUser }) => {
      const user = createTestUser();
      await registerUser(user.email, user.password, user.name);
      // Expect redirect to verification page or dashboard
      await expect(page).toHaveURL(/\/(verify|dashboard|home)/);
    });

    test('should show error for duplicate email @regression', async ({ page, registerUser }) => {
      await registerUser('testuser@example.com', 'TestPassword123!', 'Duplicate User');
      await expect(page.locator('[role="alert"]')).toBeVisible();
    });

    test('should validate password strength @regression', async ({ page }) => {
      const registerPage = new RegisterPage(page);
      await registerPage.goto();
      const user = createTestUser({ password: '123' });
      await registerPage.fillForm(user);
      await registerPage.submit();
      // Expect password strength error
      await expect(page.locator('text=/password|weak|strong|characters/i')).toBeVisible();
    });
  });

  test.describe('Logout', () => {
    test('should logout and redirect to login page @smoke', async ({ page, loginAsUser, logout }) => {
      await loginAsUser();
      await logout();
      await expect(page).toHaveURL(/\/(login|signin|\/)/);
    });

    test('should not access protected routes after logout @critical', async ({ page, loginAsUser, logout }) => {
      await loginAsUser();
      await logout();
      await page.goto('/dashboard');
      await expect(page).toHaveURL(/\/(login|signin)/);
    });
  });
});
```

Generate similar comprehensive test specs for ALL discovered flows: `profile.spec.ts`, `crud.spec.ts`, `search.spec.ts`, `payment.spec.ts`, `admin.spec.ts`, `settings.spec.ts`, `responsive.spec.ts`, `navigation.spec.ts`, `error-handling.spec.ts`.

**For each spec, include AT MINIMUM:**
- 3 happy path tests
- 2 error/edge case tests
- 1 accessibility test
- Proper setup and teardown
- Page Object usage (no raw selectors in tests)

---

## Step 4: Generate Mobile E2E Tests (if React Native/Expo project detected)

### 4.1 Check for Mobile Project

```bash
ls -la app.json 2>/dev/null
ls -la expo-env.d.ts 2>/dev/null
```

If NO mobile project is detected, skip this step entirely and note it in the output summary.

### 4.2 Install Detox (if not present)

```bash
npm install -D detox @types/detox jest-circus
npx detox init
```

### 4.3 Create Detox Configuration

Create `detox.config.js`:

```javascript
/** @type {import('detox').DetoxConfig} */
module.exports = {
  testRunner: {
    args: {
      config: 'e2e/jest.config.js',
      maxWorkers: 1,
      _: ['e2e'],
    },
    jest: {
      setupTimeout: 120000,
    },
  },
  apps: {
    'ios.debug': {
      type: 'ios.app',
      binaryPath: 'ios/build/Build/Products/Debug-iphonesimulator/App.app',
      build: 'xcodebuild -workspace ios/App.xcworkspace -scheme App -configuration Debug -sdk iphonesimulator -derivedDataPath ios/build',
    },
    'android.debug': {
      type: 'android.apk',
      binaryPath: 'android/app/build/outputs/apk/debug/app-debug.apk',
      build: 'cd android && ./gradlew assembleDebug assembleAndroidTest -DtestBuildType=debug',
    },
  },
  devices: {
    simulator: {
      type: 'ios.simulator',
      device: { type: 'iPhone 15' },
    },
    emulator: {
      type: 'android.emulator',
      device: { avdName: 'Pixel_7_API_34' },
    },
  },
  configurations: {
    'ios.sim.debug': { device: 'simulator', app: 'ios.debug' },
    'android.emu.debug': { device: 'emulator', app: 'android.debug' },
  },
};
```

### 4.4 Generate Detox Test Files

Create tests mirroring the web Playwright structure:

```
e2e/
  flows/
    auth.test.ts          # Login, register, logout on mobile
    navigation.test.ts     # Tab navigation, stack navigation, deep links
    offline.test.ts        # Offline mode, data sync, queue management
    gestures.test.ts       # Swipe, pinch, long press interactions
  helpers/
    auth.helper.ts         # Mobile auth helpers
    data.helper.ts         # Test data factories (shared with web)
  jest.config.js           # Jest config for Detox
```

Each Detox test must:
- Use `device.launchApp()` with proper reset options
- Use `element(by.id())` for testID-based selection
- Handle platform-specific behaviors (iOS vs Android)
- Test offline/online transitions
- Test push notification permissions
- Avoid arbitrary `waitFor` timeouts — use Detox's built-in synchronization

---

## Step 5: Visual Regression Tests (if --visual flag provided)

### 5.1 Create Visual Regression Spec

Create `tests/e2e/visual/screenshots.spec.ts`:

```typescript
import { test, expect } from '@playwright/test';

/**
 * Visual Regression Tests
 *
 * Captures screenshots of every page and compares against baselines.
 * On first run, baselines are created. On subsequent runs, diffs are reported.
 *
 * Dynamic content (timestamps, avatars, random data) is masked to prevent
 * false positives.
 */

// List of all pages to screenshot — populated from Step 1.2 route discovery
const PAGES_TO_SCREENSHOT: Array<{ name: string; path: string; waitFor?: string }> = [
  { name: 'home', path: '/' },
  { name: 'login', path: '/login' },
  { name: 'register', path: '/register' },
  { name: 'dashboard', path: '/dashboard' },
  { name: 'profile', path: '/profile' },
  { name: 'settings', path: '/settings' },
  // Add more pages based on route discovery
];

// Selectors for dynamic content that should be masked in screenshots
const DYNAMIC_CONTENT_MASKS = [
  '[data-testid="timestamp"]',
  '[data-testid="avatar"]',
  '[data-testid="random-id"]',
  'time',
  '.relative-time',
];

test.describe('Visual Regression — Full Page Screenshots', () => {
  for (const pageInfo of PAGES_TO_SCREENSHOT) {
    test(`${pageInfo.name} page should match baseline screenshot`, async ({ page }) => {
      await page.goto(pageInfo.path, { waitUntil: 'networkidle' });

      // Wait for specific element if needed
      if (pageInfo.waitFor) {
        await page.locator(pageInfo.waitFor).waitFor({ state: 'visible' });
      }

      // Wait for all images to load
      await page.evaluate(() => {
        return Promise.all(
          Array.from(document.images)
            .filter((img) => !img.complete)
            .map((img) => new Promise((resolve) => {
              img.onload = resolve;
              img.onerror = resolve;
            })),
        );
      });

      // Take screenshot with dynamic content masked
      await expect(page).toHaveScreenshot(`${pageInfo.name}.png`, {
        fullPage: true,
        mask: DYNAMIC_CONTENT_MASKS
          .map((sel) => page.locator(sel))
          .filter(async (loc) => (await loc.count()) > 0),
        maxDiffPixelRatio: 0.01,
        threshold: 0.2,
        animations: 'disabled',
      });
    });
  }
});

test.describe('Visual Regression — Component Screenshots', () => {
  test('navigation bar should match baseline', async ({ page }) => {
    await page.goto('/');
    await page.waitForLoadState('networkidle');

    const nav = page.locator('nav, [role="navigation"], header');
    if ((await nav.count()) > 0) {
      await expect(nav.first()).toHaveScreenshot('navigation-bar.png', {
        animations: 'disabled',
      });
    }
  });

  test('footer should match baseline', async ({ page }) => {
    await page.goto('/');
    await page.waitForLoadState('networkidle');

    const footer = page.locator('footer, [role="contentinfo"]');
    if ((await footer.count()) > 0) {
      await expect(footer.first()).toHaveScreenshot('footer.png', {
        animations: 'disabled',
      });
    }
  });

  test('sidebar should match baseline', async ({ page }) => {
    await page.goto('/dashboard');
    await page.waitForLoadState('networkidle');

    const sidebar = page.locator('[data-testid="sidebar"], aside, [role="complementary"]');
    if ((await sidebar.count()) > 0) {
      await expect(sidebar.first()).toHaveScreenshot('sidebar.png', {
        animations: 'disabled',
      });
    }
  });
});

test.describe('Visual Regression — Dark Mode', () => {
  test.use({ colorScheme: 'dark' });

  for (const pageInfo of PAGES_TO_SCREENSHOT) {
    test(`${pageInfo.name} page dark mode should match baseline`, async ({ page }) => {
      await page.goto(pageInfo.path, { waitUntil: 'networkidle' });

      if (pageInfo.waitFor) {
        await page.locator(pageInfo.waitFor).waitFor({ state: 'visible' });
      }

      await expect(page).toHaveScreenshot(`${pageInfo.name}-dark.png`, {
        fullPage: true,
        maxDiffPixelRatio: 0.01,
        animations: 'disabled',
      });
    });
  }
});
```

### 5.2 Update Visual Baselines

After generating the visual tests:

```bash
# Generate baseline screenshots (first run)
npx playwright test tests/e2e/visual/ --update-snapshots

# Compare against baselines (subsequent runs)
npx playwright test tests/e2e/visual/
```

---

## Step 6: Run Tests and Verify

### 6.1 Execute the Test Suite

```bash
# Run all E2E tests
npx playwright test 2>&1

# If tests fail, check the HTML report
npx playwright show-report 2>&1
```

### 6.2 Fix Failing Tests

If any tests fail:
1. Read the error message and stack trace
2. Check the screenshot in `test-results/` for visual context
3. Check the trace file with `npx playwright show-trace <trace-file>`
4. Determine if the failure is a test bug or an application bug
5. Fix test bugs (wrong selectors, missing waits, incorrect assertions)
6. For application bugs, note them in the output summary but do NOT modify application code

### 6.3 Verify Cross-Browser Results

```bash
# Run per-browser to isolate failures
npx playwright test --project=chromium-desktop 2>&1
npx playwright test --project=firefox-desktop 2>&1
npx playwright test --project=webkit-desktop 2>&1
npx playwright test --project=chromium-mobile 2>&1
npx playwright test --project=webkit-mobile 2>&1
npx playwright test --project=chromium-tablet 2>&1
```

---

## Step 7: Output Summary

After completing all steps, output the following summary:

```
+================================================================+
|  E2E TESTS GENERATED                                           |
+================================================================+
|                                                                |
|  PROJECT TYPE:                                                 |
|  - Web (Next.js): [Yes/No]                                    |
|  - Mobile (React Native): [Yes/No]                            |
|                                                                |
|  ROUTES DISCOVERED:                                            |
|  - Web routes: [count] routes across [count] route groups      |
|  - Mobile screens: [count] screens across [count] navigators   |
|                                                                |
|  FLOWS IDENTIFIED:                                             |
|  - Auth: [Yes/No]                                              |
|  - CRUD: [Yes/No]                                              |
|  - Payment: [Yes/No]                                           |
|  - Search: [Yes/No]                                            |
|  - Profile: [Yes/No]                                           |
|  - Settings: [Yes/No]                                          |
|  - Admin: [Yes/No]                                             |
|  - Navigation: [Yes/No]                                        |
|                                                                |
|  FILES GENERATED:                                              |
|  - Playwright config: playwright.config.ts                     |
|  - Page Objects: [count] files                                 |
|  - Flow Specs: [count] files, [count] total test cases         |
|  - Visual Tests: [count] screenshots                           |
|  - Fixtures: auth.fixture.ts, data.fixture.ts                  |
|  - Setup/Teardown: global-setup.ts, global-teardown.ts         |
|  - Detox Config: [Yes/No]                                      |
|  - Mobile Tests: [count] files                                 |
|                                                                |
|  BROWSER COVERAGE:                                             |
|  - Chromium Desktop (1280x720): [pass/fail]                    |
|  - Firefox Desktop (1280x720): [pass/fail]                     |
|  - WebKit Desktop (1280x720): [pass/fail]                      |
|  - Chromium Tablet (768x1024): [pass/fail]                     |
|  - Chromium Mobile (375x667): [pass/fail]                      |
|  - WebKit Mobile (375x667): [pass/fail]                        |
|                                                                |
|  COMMANDS:                                                     |
|  - Run all:       npx playwright test                          |
|  - Run headed:    npx playwright test --headed                 |
|  - Run UI mode:   npx playwright test --ui                     |
|  - Run debug:     npx playwright test --debug                  |
|  - View report:   npx playwright show-report                   |
|  - Run visual:    npx playwright test tests/e2e/visual/        |
|  - Update snaps:  npx playwright test --update-snapshots       |
|  - Run chromium:  npx playwright test --project=chromium-desktop|
|  - Run mobile:    npx playwright test --project=chromium-mobile |
|                                                                |
+================================================================+
```

If any tests failed, also output:

```
+================================================================+
|  FAILURES REQUIRING ATTENTION                                  |
+================================================================+
|                                                                |
|  [test-name] — [browser] — [error-summary]                    |
|  Screenshot: test-results/[path-to-screenshot]                 |
|  Trace: test-results/[path-to-trace]                           |
|                                                                |
|  Likely cause: [test bug / application bug / flaky test]       |
|  Suggested fix: [description]                                  |
|                                                                |
+================================================================+
```

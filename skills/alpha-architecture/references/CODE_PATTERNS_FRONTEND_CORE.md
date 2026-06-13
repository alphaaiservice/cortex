# CODE_PATTERNS_FRONTEND_CORE.md — Core Architecture & Infrastructure
# Part 1 of 3: Directory Structure, App Router, Route Groups, Providers, Middleware, Page State
# Language: TypeScript/TSX | Framework: Next.js 15+ | UI: shadcn/ui + Tailwind
# ═══════════════════════════════════════════════════════════════════
# See also: CODE_PATTERNS_FRONTEND_PRODUCTION.md (⭐ the production-ready bar — fonts & color, real data, friendly errors — READ FIRST)
#           CODE_PATTERNS_FRONTEND_PAGES.md (layouts + page templates)
#           CODE_PATTERNS_FRONTEND_UX.md (components + UX patterns)


# ╔══════════════════════════════════════════════════════════════════╗
# ║  1. FRONTEND DIRECTORY STRUCTURE                                ║
# ╚══════════════════════════════════════════════════════════════════╝
#
# This is the ENFORCED directory layout for every frontend project.
# Route groups organize pages by auth context without URL segments.
# Components are split into ui/ (shadcn), shared/ (app-level), layouts/.

```
frontend/
├── app/
│   ├── (auth)/                      # Public auth pages — centered card layout
│   │   ├── login/page.tsx
│   │   ├── register/page.tsx
│   │   ├── forgot-password/page.tsx
│   │   └── layout.tsx               # Centered card, no sidebar
│   ├── (dashboard)/                 # Main app — sidebar + header layout
│   │   ├── page.tsx                 # Dashboard home (stats + charts)
│   │   ├── [entity]/
│   │   │   ├── page.tsx             # Entity list (table + search + filter)
│   │   │   ├── [id]/page.tsx        # Entity detail (tabs + actions)
│   │   │   ├── [id]/edit/page.tsx   # Entity edit form
│   │   │   └── new/page.tsx         # Entity create form
│   │   ├── settings/
│   │   │   └── page.tsx             # Settings (tabbed forms)
│   │   ├── layout.tsx               # Sidebar + header layout
│   │   ├── loading.tsx              # Dashboard skeleton
│   │   └── error.tsx                # Dashboard error boundary
│   ├── (marketing)/                 # Public pages — navbar + footer layout
│   │   ├── page.tsx                 # Landing page
│   │   ├── pricing/page.tsx
│   │   └── layout.tsx
│   ├── (admin)/                     # Admin panel — admin sidebar layout
│   │   ├── users/page.tsx
│   │   ├── analytics/page.tsx
│   │   ├── layout.tsx
│   │   └── loading.tsx
│   ├── (legal)/                     # Legal pages — narrow prose layout
│   │   ├── terms/page.tsx
│   │   ├── privacy/page.tsx
│   │   └── layout.tsx
│   ├── layout.tsx                   # Root layout (providers + font)
│   ├── loading.tsx                  # Root loading skeleton
│   ├── error.tsx                    # Root error boundary
│   ├── not-found.tsx                # Global 404 page
│   └── globals.css                  # Tailwind + CSS variables
├── components/
│   ├── ui/                          # shadcn/ui primitives (auto-generated)
│   ├── shared/                      # Reusable app components
│   │   ├── page-header.tsx
│   │   ├── page-content.tsx         # 4-state pattern (loading/error/empty/data)
│   │   ├── data-table.tsx
│   │   ├── form-field.tsx
│   │   ├── empty-state.tsx
│   │   ├── confirm-dialog.tsx
│   │   ├── search-input.tsx
│   │   ├── pagination.tsx
│   │   ├── stat-card.tsx
│   │   ├── skeletons.tsx
│   │   ├── json-ld.tsx
│   │   ├── command-palette.tsx
│   │   └── theme-toggle.tsx
│   └── layouts/
│       ├── dashboard-layout.tsx
│       ├── sidebar.tsx
│       ├── header.tsx
│       └── breadcrumbs.tsx
├── hooks/
│   ├── useAuth.ts
│   ├── useDebounce.ts
│   └── useMediaQuery.ts
├── lib/
│   ├── api.ts                       # Axios instance + interceptors
│   ├── query-client.ts              # TanStack Query client config
│   ├── utils.ts                     # cn() helper + formatters
│   └── validations/                 # Zod schemas per entity
├── providers/
│   └── index.tsx                    # Provider composition (Theme → Query → Toast)
├── types/
│   └── index.ts                     # Shared TypeScript types
├── middleware.ts                     # Auth redirect logic
├── next.config.ts
├── tailwind.config.ts
├── tsconfig.json
└── package.json
```


# ╔══════════════════════════════════════════════════════════════════╗
# ║  2. NEXT.JS APP ROUTER CONVENTIONS                              ║
# ╚══════════════════════════════════════════════════════════════════╝
#
# Every route group MUST have: layout.tsx, loading.tsx, error.tsx.
# Pages are Server Components by default — add "use client" only when needed.
# Special files are auto-detected by Next.js and rendered at the right time.

# ----------------------------------------------------------------------
# 2a. layout.tsx — Root Layout (wraps entire app)
# ----------------------------------------------------------------------

```tsx
// app/layout.tsx
import type { Metadata } from "next";
import { Inter } from "next/font/google";
import "./globals.css";
import { Providers } from "@/providers";

const inter = Inter({ subsets: ["latin"] });

export const metadata: Metadata = {
  title: { default: "APP_NAME", template: "%s | APP_NAME" },
  description: "APP_DESCRIPTION",
  metadataBase: new URL(process.env.NEXT_PUBLIC_APP_URL || "http://localhost:3000"),
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" suppressHydrationWarning>
      <body className={inter.className}>
        <Providers>{children}</Providers>
      </body>
    </html>
  );
}
```

# ----------------------------------------------------------------------
# 2b. loading.tsx — Route-level Loading UI
# ----------------------------------------------------------------------
# Rendered automatically by Next.js while the page component streams.
# MUST show a skeleton that matches the page layout (NEVER a spinner).

```tsx
// app/(dashboard)/loading.tsx
import { Skeleton } from "@/components/ui/skeleton";

export default function DashboardLoading() {
  return (
    <div className="flex flex-col gap-6 p-6">
      <div className="flex items-center justify-between">
        <div className="space-y-2">
          <Skeleton className="h-8 w-48" />
          <Skeleton className="h-4 w-72" />
        </div>
        <Skeleton className="h-10 w-32" />
      </div>
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
        {Array.from({ length: 4 }).map((_, i) => (
          <Skeleton key={i} className="h-28 rounded-xl" />
        ))}
      </div>
      <div className="space-y-3">
        <Skeleton className="h-10 w-full" />
        {Array.from({ length: 5 }).map((_, i) => (
          <Skeleton key={i} className="h-14 w-full" />
        ))}
      </div>
    </div>
  );
}
```

# ----------------------------------------------------------------------
# 2c. error.tsx — Route-level Error Boundary
# ----------------------------------------------------------------------
# MUST be "use client". NEVER show raw error.stack to the user.

```tsx
// app/(dashboard)/error.tsx
"use client";

import { useEffect } from "react";
import { AlertTriangle } from "lucide-react";
import { Button } from "@/components/ui/button";

export default function DashboardError({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  useEffect(() => {
    console.error("Dashboard error:", error);
  }, [error]);

  return (
    <div className="flex flex-col items-center justify-center min-h-[50vh] gap-4">
      <AlertTriangle className="h-12 w-12 text-destructive" />
      <h2 className="text-xl font-semibold">Something went wrong</h2>
      <p className="text-muted-foreground text-center max-w-md">
        {error.message || "An unexpected error occurred. Please try again."}
      </p>
      <div className="flex gap-3">
        <Button onClick={reset} variant="outline">Try Again</Button>
        <Button asChild variant="ghost"><a href="/dashboard">Go to Dashboard</a></Button>
      </div>
    </div>
  );
}
```

# ----------------------------------------------------------------------
# 2d. not-found.tsx — Global 404 Page
# ----------------------------------------------------------------------

```tsx
// app/not-found.tsx
import Link from "next/link";
import { FileQuestion } from "lucide-react";
import { Button } from "@/components/ui/button";

export default function NotFound() {
  return (
    <div className="flex flex-col items-center justify-center min-h-screen gap-4">
      <FileQuestion className="h-16 w-16 text-muted-foreground" />
      <h1 className="text-4xl font-bold">404</h1>
      <p className="text-muted-foreground text-lg">The page you are looking for does not exist.</p>
      <Button asChild><Link href="/">Go Home</Link></Button>
    </div>
  );
}
```

# ----------------------------------------------------------------------
# 2e. page.tsx — Standard Page Pattern
# ----------------------------------------------------------------------
# Server component exports metadata + delegates to client component.

```tsx
// app/(dashboard)/[entity]/page.tsx
import type { Metadata } from "next";
import { EntityListClient } from "./entity-list-client";

export const metadata: Metadata = {
  title: "Entities",
  description: "Manage your entities.",
};

export default function EntityListPage() {
  return <EntityListClient />;
}
```


# ╔══════════════════════════════════════════════════════════════════╗
# ║  3. ROUTE GROUPS                                                ║
# ╚══════════════════════════════════════════════════════════════════╝
#
# Group        | Purpose                      | Auth   | Layout
# -------------|------------------------------|--------|---------------------------
# (auth)       | Login, register, reset       | Public | Centered card, no chrome
# (dashboard)  | Main app CRUD pages          | JWT    | Sidebar + header
# (marketing)  | Landing, pricing, about      | Public | Navbar + footer
# (admin)      | User mgmt, analytics         | Admin  | Admin sidebar + header
# (legal)      | Terms, privacy, cookies      | Public | Narrow prose column

```tsx
// app/(auth)/layout.tsx
export default function AuthLayout({ children }: { children: React.ReactNode }) {
  return (
    <div className="flex min-h-screen items-center justify-center bg-muted/40 p-4">
      <div className="w-full max-w-md">{children}</div>
    </div>
  );
}
```

```tsx
// app/(dashboard)/layout.tsx
import { Sidebar } from "@/components/layouts/sidebar";
import { Header } from "@/components/layouts/header";

export default function DashboardLayout({ children }: { children: React.ReactNode }) {
  return (
    <div className="flex h-screen overflow-hidden">
      <Sidebar />
      <div className="flex flex-1 flex-col overflow-hidden">
        <Header />
        <main className="flex-1 overflow-y-auto bg-muted/20">{children}</main>
      </div>
    </div>
  );
}
```

```tsx
// app/(marketing)/layout.tsx
import Link from "next/link";
import { Button } from "@/components/ui/button";

export default function MarketingLayout({ children }: { children: React.ReactNode }) {
  return (
    <div className="flex min-h-screen flex-col">
      <header className="sticky top-0 z-50 border-b bg-background/80 backdrop-blur-sm">
        <div className="mx-auto flex h-16 max-w-7xl items-center justify-between px-4">
          <Link href="/" className="text-xl font-bold">APP_NAME</Link>
          <nav className="hidden md:flex items-center gap-6">
            <Link href="/pricing" className="text-sm text-muted-foreground hover:text-foreground">Pricing</Link>
            <Button asChild variant="ghost" size="sm"><Link href="/login">Sign In</Link></Button>
            <Button asChild size="sm"><Link href="/register">Get Started</Link></Button>
          </nav>
        </div>
      </header>
      <main className="flex-1">{children}</main>
      <footer className="border-t py-8">
        <div className="mx-auto max-w-7xl px-4 text-center text-sm text-muted-foreground">
          &copy; {new Date().getFullYear()} APP_NAME. All rights reserved.
          <div className="mt-2 flex justify-center gap-4">
            <Link href="/terms" className="hover:text-foreground">Terms</Link>
            <Link href="/privacy" className="hover:text-foreground">Privacy</Link>
          </div>
        </div>
      </footer>
    </div>
  );
}
```

```tsx
// app/(admin)/layout.tsx
import { Sidebar } from "@/components/layouts/sidebar";
import { Header } from "@/components/layouts/header";

const adminNavItems = [
  { label: "Users", href: "/admin/users", icon: "Users" },
  { label: "Analytics", href: "/admin/analytics", icon: "BarChart3" },
  { label: "Settings", href: "/admin/settings", icon: "Settings" },
];

export default function AdminLayout({ children }: { children: React.ReactNode }) {
  return (
    <div className="flex h-screen overflow-hidden">
      <Sidebar items={adminNavItems} title="Admin Panel" />
      <div className="flex flex-1 flex-col overflow-hidden">
        <Header />
        <main className="flex-1 overflow-y-auto bg-muted/20">{children}</main>
      </div>
    </div>
  );
}
```

```tsx
// app/(legal)/layout.tsx
import Link from "next/link";

export default function LegalLayout({ children }: { children: React.ReactNode }) {
  return (
    <div className="min-h-screen bg-background">
      <header className="border-b">
        <div className="mx-auto flex h-14 max-w-3xl items-center px-4">
          <Link href="/" className="text-lg font-semibold">APP_NAME</Link>
        </div>
      </header>
      <main className="mx-auto max-w-3xl px-4 py-12 prose prose-neutral dark:prose-invert">
        {children}
      </main>
    </div>
  );
}
```


# ╔══════════════════════════════════════════════════════════════════╗
# ║  4. PROVIDER HIERARCHY                                         ║
# ╚══════════════════════════════════════════════════════════════════╝
#
# ORDER: ThemeProvider → QueryClientProvider → Toaster → ReactQueryDevtools
# All composed in one file, wrapped in root layout.

```tsx
// providers/index.tsx
"use client";

import { useState } from "react";
import { ThemeProvider } from "next-themes";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { ReactQueryDevtools } from "@tanstack/react-query-devtools";
import { Toaster } from "sonner";

export function Providers({ children }: { children: React.ReactNode }) {
  const [queryClient] = useState(
    () =>
      new QueryClient({
        defaultOptions: {
          queries: {
            staleTime: 60 * 1000,
            retry: 1,
            refetchOnWindowFocus: false,
          },
          mutations: { retry: 0 },
        },
      })
  );

  return (
    <ThemeProvider attribute="class" defaultTheme="system" enableSystem disableTransitionOnChange>
      <QueryClientProvider client={queryClient}>
        {children}
        <Toaster position="top-right" richColors closeButton toastOptions={{ duration: 4000 }} />
        <ReactQueryDevtools initialIsOpen={false} />
      </QueryClientProvider>
    </ThemeProvider>
  );
}
```


# ╔══════════════════════════════════════════════════════════════════╗
# ║  5. MIDDLEWARE AUTH                                              ║
# ╚══════════════════════════════════════════════════════════════════╝
#
# Runs on Edge Runtime BEFORE every request. Checks JWT cookie.
# - Skip static assets and API routes
# - Redirect authenticated users away from auth pages
# - Redirect unauthenticated users to /login with callbackUrl
# - Admin role check via JWT payload decode
#
# ┌─────────────────────────────────────────────────────────────┐
# │  HARD RULE: ALL auth verification happens HERE in           │
# │  middleware.ts — NEVER in page/route components.            │
# │                                                             │
# │  Pages may use useAuth() for user DATA (name, avatar) and  │
# │  actions (logout) — but NEVER for route protection.         │
# │  middleware.ts is the SINGLE source of truth for:           │
# │  • Is the user authenticated?                               │
# │  • Does the user have the required role?                    │
# │  • Should the user be redirected?                           │
# │                                                             │
# │  ❌ NEVER: if (!user) redirect("/login") inside a page     │
# │  ❌ NEVER: useEffect(() => { if (!token) router.push() })  │
# │  ❌ NEVER: <ProtectedRoute> wrapper components             │
# │  ✅ ALWAYS: middleware.ts handles all auth redirects        │
# └─────────────────────────────────────────────────────────────┘

```tsx
// middleware.ts
import { NextResponse } from "next/server";
import type { NextRequest } from "next/server";

const PUBLIC_ROUTES = ["/", "/login", "/register", "/forgot-password", "/pricing", "/terms", "/privacy"];
const AUTH_ROUTES = ["/login", "/register", "/forgot-password"];
const ADMIN_ROUTES = ["/admin"];

export function middleware(request: NextRequest) {
  const { pathname } = request.nextUrl;
  const token = request.cookies.get("access_token")?.value;

  if (pathname.startsWith("/_next") || pathname.startsWith("/api") || pathname.includes(".")) {
    return NextResponse.next();
  }

  const isPublicRoute = PUBLIC_ROUTES.some((route) => pathname === route || pathname.startsWith(`${route}/`));
  const isAuthRoute = AUTH_ROUTES.some((route) => pathname === route);
  const isAdminRoute = ADMIN_ROUTES.some((route) => pathname.startsWith(route));

  if (isAuthRoute && token) {
    return NextResponse.redirect(new URL("/dashboard", request.url));
  }

  if (!isPublicRoute && !token) {
    const loginUrl = new URL("/login", request.url);
    loginUrl.searchParams.set("callbackUrl", pathname);
    return NextResponse.redirect(loginUrl);
  }

  if (isAdminRoute && token) {
    try {
      const payload = JSON.parse(Buffer.from(token.split(".")[1], "base64").toString());
      if (payload.role !== "admin") {
        return NextResponse.redirect(new URL("/dashboard", request.url));
      }
    } catch {
      const loginUrl = new URL("/login", request.url);
      loginUrl.searchParams.set("callbackUrl", pathname);
      return NextResponse.redirect(loginUrl);
    }
  }

  return NextResponse.next();
}

export const config = {
  matcher: ["/((?!_next/static|_next/image|favicon.ico).*)"],
};
```


# ╔══════════════════════════════════════════════════════════════════╗
# ║  6. PAGE STATE PATTERN                                          ║
# ╚══════════════════════════════════════════════════════════════════╝
#
# EVERY page that fetches data MUST handle exactly 4 states:
#
#   State     | What to show                       | NEVER show
#   ----------|------------------------------------|---------------------------
#   Loading   | Skeleton matching page layout       | Spinner, blank page
#   Error     | Friendly message + retry button     | Raw API error, stack trace
#   Empty     | Illustration + title + CTA          | Blank page, "No data"
#   Data      | Actual content                      | N/A

```tsx
// components/shared/page-content.tsx
"use client";

import { AlertTriangle } from "lucide-react";
import { Button } from "@/components/ui/button";
import { EmptyState } from "@/components/shared/empty-state";

interface PageContentProps<T> {
  isLoading: boolean;
  isError: boolean;
  error?: Error | null;
  data: T[] | T | undefined | null;
  onRetry: () => void;
  loadingSkeleton: React.ReactNode;
  emptyState: {
    icon: React.ReactNode;
    title: string;
    description: string;
    actionLabel?: string;
    onAction?: () => void;
  };
  children: (data: T[] | T) => React.ReactNode;
}

export function PageContent<T>({
  isLoading, isError, error, data, onRetry, loadingSkeleton, emptyState, children,
}: PageContentProps<T>) {
  if (isLoading) return <>{loadingSkeleton}</>;

  if (isError) {
    return (
      <div className="flex flex-col items-center justify-center min-h-[40vh] gap-4">
        <AlertTriangle className="h-12 w-12 text-destructive" />
        <h3 className="text-lg font-semibold">Failed to load data</h3>
        <p className="text-muted-foreground text-center max-w-md">
          {error?.message || "Something went wrong. Please try again."}
        </p>
        <Button onClick={onRetry} variant="outline">Try Again</Button>
      </div>
    );
  }

  const isEmpty = Array.isArray(data) ? data.length === 0 : !data;
  if (isEmpty) return <EmptyState {...emptyState} />;

  return <>{children(data as T[] | T)}</>;
}
```

```tsx
// components/shared/empty-state.tsx
import { Button } from "@/components/ui/button";

interface EmptyStateProps {
  icon: React.ReactNode;
  title: string;
  description: string;
  actionLabel?: string;
  onAction?: () => void;
}

export function EmptyState({ icon, title, description, actionLabel, onAction }: EmptyStateProps) {
  return (
    <div className="flex flex-col items-center justify-center min-h-[40vh] gap-4 text-center">
      <div className="rounded-full bg-muted p-4">{icon}</div>
      <h3 className="text-lg font-semibold">{title}</h3>
      <p className="text-muted-foreground max-w-sm">{description}</p>
      {actionLabel && onAction && <Button onClick={onAction}>{actionLabel}</Button>}
    </div>
  );
}
```


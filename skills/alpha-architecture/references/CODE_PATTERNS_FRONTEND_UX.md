# CODE_PATTERNS_FRONTEND_UX.md — Components & UX Patterns
# Part 3 of 3: Reusable Components, Responsive, Skeletons, SEO, Animations, Dark Mode, Cmd+K
# Language: TypeScript/TSX | Framework: Next.js 15+ | UI: shadcn/ui + Tailwind
# ═══════════════════════════════════════════════════════════════════
# See also: CODE_PATTERNS_FRONTEND_CORE.md (core architecture)
#           CODE_PATTERNS_FRONTEND_PAGES.md (layouts + page templates)


# ╔══════════════════════════════════════════════════════════════════╗
# ║  9. REUSABLE COMPONENTS                                        ║
# ╚══════════════════════════════════════════════════════════════════╝

```tsx
// components/shared/page-header.tsx
import { Button } from "@/components/ui/button";
import { LucideIcon } from "lucide-react";

interface PageHeaderProps {
  title: string;
  description?: string;
  actions?: React.ReactNode;
}

export function PageHeader({ title, description, actions }: PageHeaderProps) {
  return (
    <div className="flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between">
      <div>
        <h1 className="text-2xl font-bold tracking-tight">{title}</h1>
        {description && <p className="text-muted-foreground">{description}</p>}
      </div>
      {actions && <div className="flex gap-2">{actions}</div>}
    </div>
  );
}
```

```tsx
// components/shared/search-input.tsx
"use client";

import { Search, X } from "lucide-react";
import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";

interface SearchInputProps {
  value: string;
  onChange: (value: string) => void;
  placeholder?: string;
}

export function SearchInput({ value, onChange, placeholder = "Search..." }: SearchInputProps) {
  return (
    <div className="relative max-w-sm">
      <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground" />
      <Input
        value={value}
        onChange={(e) => onChange(e.target.value)}
        placeholder={placeholder}
        className="pl-9 pr-9"
      />
      {value && (
        <Button variant="ghost" size="icon" className="absolute right-1 top-1/2 -translate-y-1/2 h-7 w-7" onClick={() => onChange("")}>
          <X className="h-3 w-3" />
        </Button>
      )}
    </div>
  );
}
```

```tsx
// components/shared/confirm-dialog.tsx
"use client";

import { Loader2 } from "lucide-react";
import {
  AlertDialog, AlertDialogAction, AlertDialogCancel, AlertDialogContent,
  AlertDialogDescription, AlertDialogFooter, AlertDialogHeader, AlertDialogTitle,
} from "@/components/ui/alert-dialog";
import { buttonVariants } from "@/components/ui/button";

interface ConfirmDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  title: string;
  description: string;
  confirmLabel?: string;
  variant?: "destructive" | "default";
  isLoading?: boolean;
  onConfirm: () => void;
}

export function ConfirmDialog({ open, onOpenChange, title, description, confirmLabel = "Confirm", variant = "default", isLoading, onConfirm }: ConfirmDialogProps) {
  return (
    <AlertDialog open={open} onOpenChange={onOpenChange}>
      <AlertDialogContent>
        <AlertDialogHeader>
          <AlertDialogTitle>{title}</AlertDialogTitle>
          <AlertDialogDescription>{description}</AlertDialogDescription>
        </AlertDialogHeader>
        <AlertDialogFooter>
          <AlertDialogCancel disabled={isLoading}>Cancel</AlertDialogCancel>
          <AlertDialogAction className={buttonVariants({ variant })} disabled={isLoading} onClick={onConfirm}>
            {isLoading && <Loader2 className="mr-2 h-4 w-4 animate-spin" />}{confirmLabel}
          </AlertDialogAction>
        </AlertDialogFooter>
      </AlertDialogContent>
    </AlertDialog>
  );
}
```

```tsx
// components/shared/stat-card.tsx
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Skeleton } from "@/components/ui/skeleton";
import { ArrowUpRight, ArrowDownRight } from "lucide-react";

interface StatCardProps {
  title: string;
  value: string;
  trend?: number;
  icon: React.ElementType;
  loading?: boolean;
}

export function StatCard({ title, value, trend, icon: Icon, loading }: StatCardProps) {
  if (loading) {
    return (<Card><CardHeader className="flex flex-row items-center justify-between pb-2"><Skeleton className="h-4 w-24" /><Skeleton className="h-4 w-4" /></CardHeader><CardContent><Skeleton className="h-7 w-32" /><Skeleton className="mt-1 h-3 w-20" /></CardContent></Card>);
  }
  const isPositive = (trend ?? 0) >= 0;
  return (
    <Card>
      <CardHeader className="flex flex-row items-center justify-between pb-2">
        <CardTitle className="text-sm font-medium text-muted-foreground">{title}</CardTitle>
        <Icon className="h-4 w-4 text-muted-foreground" />
      </CardHeader>
      <CardContent>
        <div className="text-2xl font-bold">{value}</div>
        {trend !== undefined && (
          <p className={`flex items-center text-xs ${isPositive ? "text-green-600" : "text-red-600"}`}>
            {isPositive ? <ArrowUpRight className="mr-1 h-3 w-3" /> : <ArrowDownRight className="mr-1 h-3 w-3" />}
            {Math.abs(trend)}% from last month
          </p>
        )}
      </CardContent>
    </Card>
  );
}
```


# ╔══════════════════════════════════════════════════════════════════╗
# ║  10. RESPONSIVE PATTERNS                                       ║
# ╚══════════════════════════════════════════════════════════════════╝

# Mobile-first Tailwind patterns — use these EVERYWHERE:
#
# Responsive grid:         grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4 md:gap-6
# Sidebar collapse:        hidden md:flex md:w-64 lg:w-72 flex-col
# Touch targets:           h-11 px-4 md:h-10  (min 44px on mobile)
# Responsive typography:   text-2xl md:text-3xl lg:text-4xl font-bold
# Responsive padding:      p-4 md:p-6 lg:p-8
# Stack to row:            flex flex-col sm:flex-row gap-2 sm:gap-4

```tsx
// hooks/useMediaQuery.ts
import { useState, useEffect } from "react";

export function useMediaQuery(query: string): boolean {
  const [matches, setMatches] = useState(false);

  useEffect(() => {
    const media = window.matchMedia(query);
    setMatches(media.matches);
    const listener = (event: MediaQueryListEvent) => setMatches(event.matches);
    media.addEventListener("change", listener);
    return () => media.removeEventListener("change", listener);
  }, [query]);

  return matches;
}
```

```tsx
// hooks/useDebounce.ts
import { useState, useEffect } from "react";

export function useDebounce<T>(value: T, delay: number): T {
  const [debouncedValue, setDebouncedValue] = useState(value);

  useEffect(() => {
    const timer = setTimeout(() => setDebouncedValue(value), delay);
    return () => clearTimeout(timer);
  }, [value, delay]);

  return debouncedValue;
}
```


# ╔══════════════════════════════════════════════════════════════════╗
# ║  11. LOADING & SKELETON                                        ║
# ╚══════════════════════════════════════════════════════════════════╝
#
# RULES:
# - NEVER use a spinner/Loader2 as a page loading state
# - ALWAYS use content-shaped skeletons
# - Skeletons must match the layout they replace

```tsx
// components/shared/skeletons.tsx
import { Skeleton } from "@/components/ui/skeleton";
import { Card, CardContent, CardHeader } from "@/components/ui/card";

export function PageSkeleton() {
  return (
    <div className="space-y-6">
      <div className="space-y-2"><Skeleton className="h-8 w-48" /><Skeleton className="h-4 w-72" /></div>
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
        {Array.from({ length: 4 }).map((_, i) => <CardSkeleton key={i} />)}
      </div>
      <TableSkeleton rows={5} columns={5} />
    </div>
  );
}

export function TableSkeleton({ rows = 5, columns = 4 }: { rows?: number; columns?: number }) {
  return (
    <div className="rounded-md border">
      <div className="border-b"><div className="flex items-center gap-4 p-4">{Array.from({ length: columns }).map((_, i) => <Skeleton key={i} className="h-4 flex-1" />)}</div></div>
      {Array.from({ length: rows }).map((_, rowIdx) => (
        <div key={rowIdx} className="flex items-center gap-4 border-b p-4 last:border-b-0">
          {Array.from({ length: columns }).map((_, colIdx) => <Skeleton key={colIdx} className="h-4 flex-1" />)}
        </div>
      ))}
    </div>
  );
}

export function CardSkeleton() {
  return (<Card><CardContent className="p-6"><div className="flex items-center gap-4"><Skeleton className="h-12 w-12 rounded-lg" /><div className="flex-1 space-y-2"><Skeleton className="h-3 w-20" /><Skeleton className="h-7 w-28" /></div></div></CardContent></Card>);
}

export function FormSkeleton({ fields = 4 }: { fields?: number }) {
  return (
    <div className="space-y-6">
      <div className="space-y-2"><Skeleton className="h-8 w-48" /><Skeleton className="h-4 w-72" /></div>
      <Card><CardContent className="p-6 space-y-6">
        {Array.from({ length: fields }).map((_, i) => (<div key={i} className="space-y-2"><Skeleton className="h-4 w-24" /><Skeleton className="h-10 w-full" /></div>))}
        <div className="flex justify-end gap-2 pt-4"><Skeleton className="h-10 w-20" /><Skeleton className="h-10 w-24" /></div>
      </CardContent></Card>
    </div>
  );
}

export function DetailSkeleton() {
  return (
    <div className="space-y-6">
      <div className="flex items-center gap-4"><Skeleton className="h-16 w-16 rounded-full" /><div className="space-y-2"><Skeleton className="h-6 w-40" /><Skeleton className="h-4 w-56" /></div></div>
      <div className="flex gap-2 border-b pb-2">{Array.from({ length: 4 }).map((_, i) => <Skeleton key={i} className="h-8 w-20" />)}</div>
      <Card><CardHeader><Skeleton className="h-5 w-32" /></CardHeader><CardContent className="space-y-4">
        {Array.from({ length: 5 }).map((_, i) => (<div key={i} className="flex justify-between"><Skeleton className="h-4 w-24" /><Skeleton className="h-4 w-40" /></div>))}
      </CardContent></Card>
    </div>
  );
}

export function ListSkeleton({ items = 5 }: { items?: number }) {
  return (
    <div className="space-y-3">
      {Array.from({ length: items }).map((_, i) => (
        <div key={i} className="flex items-center gap-4 rounded-lg border p-4">
          <Skeleton className="h-10 w-10 rounded-full" />
          <div className="flex-1 space-y-2"><Skeleton className="h-4 w-48" /><Skeleton className="h-3 w-32" /></div>
          <Skeleton className="h-8 w-16" />
        </div>
      ))}
    </div>
  );
}
```


# ╔══════════════════════════════════════════════════════════════════╗
# ║  12. SEO & METADATA                                            ║
# ╚══════════════════════════════════════════════════════════════════╝

```tsx
// Dynamic metadata for detail pages
// app/dashboard/users/[id]/page.tsx
import type { Metadata } from "next";

export async function generateMetadata({ params }: { params: { id: string } }): Promise<Metadata> {
  const user = await fetch(`${process.env.API_URL}/users/${params.id}`).then((r) => r.json());
  return {
    title: user.name,
    description: `Profile for ${user.name}`,
    openGraph: { title: user.name, description: `Profile for ${user.name}`, images: user.avatar ? [user.avatar] : [] },
  };
}
```

```tsx
// components/shared/json-ld.tsx
export function JsonLd({ data }: { data: Record<string, unknown> }) {
  return <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(data) }} />;
}
```

```tsx
// app/sitemap.ts
import { MetadataRoute } from "next";

export default function sitemap(): MetadataRoute.Sitemap {
  const baseUrl = process.env.NEXT_PUBLIC_APP_URL || "https://example.com";
  return [
    { url: baseUrl, lastModified: new Date(), changeFrequency: "daily", priority: 1 },
    { url: `${baseUrl}/pricing`, lastModified: new Date(), changeFrequency: "weekly", priority: 0.9 },
  ];
}
```

```tsx
// app/robots.ts
import { MetadataRoute } from "next";

export default function robots(): MetadataRoute.Robots {
  const baseUrl = process.env.NEXT_PUBLIC_APP_URL || "https://example.com";
  return { rules: { userAgent: "*", allow: "/", disallow: ["/dashboard/", "/api/"] }, sitemap: `${baseUrl}/sitemap.xml` };
}
```


# ╔══════════════════════════════════════════════════════════════════╗
# ║  13. ANIMATION & TRANSITIONS                                   ║
# ╚══════════════════════════════════════════════════════════════════╝

```tsx
// components/shared/page-transition.tsx
"use client";
import { motion } from "framer-motion";

export function PageTransition({ children }: { children: React.ReactNode }) {
  return (
    <motion.div initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0, y: -20 }} transition={{ duration: 0.3, ease: "easeOut" }}>
      {children}
    </motion.div>
  );
}
```

```tsx
// components/shared/stagger-list.tsx
"use client";
import { motion } from "framer-motion";

const containerVariants = { hidden: { opacity: 0 }, show: { opacity: 1, transition: { staggerChildren: 0.1 } } };
const itemVariants = { hidden: { opacity: 0, y: 20 }, show: { opacity: 1, y: 0 } };

export function StaggerList({ children }: { children: React.ReactNode[] }) {
  return (
    <motion.div variants={containerVariants} initial="hidden" animate="show" className="space-y-3">
      {children.map((child, index) => (<motion.div key={index} variants={itemVariants}>{child}</motion.div>))}
    </motion.div>
  );
}
```

```tsx
// components/shared/animated-card.tsx
"use client";
import { motion } from "framer-motion";

export function AnimatedCard({ children, className }: { children: React.ReactNode; className?: string }) {
  return (
    <motion.div whileHover={{ scale: 1.02, boxShadow: "0 4px 20px rgba(0,0,0,0.1)" }} whileTap={{ scale: 0.98 }} transition={{ type: "spring", stiffness: 300, damping: 20 }} className={className}>
      {children}
    </motion.div>
  );
}
```


# ╔══════════════════════════════════════════════════════════════════╗
# ║  14. TOAST & FEEDBACK                                          ║
# ╚══════════════════════════════════════════════════════════════════╝
#
# All user feedback uses Sonner. NEVER use window.alert.

```tsx
import { toast } from "sonner";

// Success after mutation
// toast.success("User created successfully");

// Error after mutation
// toast.error("Failed to create user", { description: error.message });

// Promise toast for long-running async operations
// toast.promise(exportData(), { loading: "Exporting data...", success: "Export complete!", error: "Export failed" });

// Action toast with undo
// toast("Item deleted", { action: { label: "Undo", onClick: () => undoDelete(id) }, duration: 5000 });

// Info/warning
// toast.info("Your session will expire in 5 minutes");
// toast.warning("This action cannot be undone");
```


# ╔══════════════════════════════════════════════════════════════════╗
# ║  15. DARK MODE                                                  ║
# ╚══════════════════════════════════════════════════════════════════╝

```tsx
// components/shared/theme-toggle.tsx
"use client";

import { useTheme } from "next-themes";
import { Moon, Sun, Monitor } from "lucide-react";
import { Button } from "@/components/ui/button";
import {
  DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";

export function ThemeToggle() {
  const { setTheme } = useTheme();
  return (
    <DropdownMenu>
      <DropdownMenuTrigger asChild>
        <Button variant="ghost" size="icon" className="h-9 w-9">
          <Sun className="h-4 w-4 rotate-0 scale-100 transition-all dark:-rotate-90 dark:scale-0" />
          <Moon className="absolute h-4 w-4 rotate-90 scale-0 transition-all dark:rotate-0 dark:scale-100" />
          <span className="sr-only">Toggle theme</span>
        </Button>
      </DropdownMenuTrigger>
      <DropdownMenuContent align="end">
        <DropdownMenuItem onClick={() => setTheme("light")}><Sun className="mr-2 h-4 w-4" />Light</DropdownMenuItem>
        <DropdownMenuItem onClick={() => setTheme("dark")}><Moon className="mr-2 h-4 w-4" />Dark</DropdownMenuItem>
        <DropdownMenuItem onClick={() => setTheme("system")}><Monitor className="mr-2 h-4 w-4" />System</DropdownMenuItem>
      </DropdownMenuContent>
    </DropdownMenu>
  );
}
```

# Color token rules — MANDATORY:
#
#   bg-background, text-foreground, bg-card, text-card-foreground
#   bg-muted, text-muted-foreground, border-border
#   bg-primary, text-primary-foreground, bg-destructive, bg-accent
#
#   NEVER use: bg-white, bg-black, text-gray-*, bg-gray-*, bg-slate-*
#   These break dark mode. Always use semantic tokens.


# ╔══════════════════════════════════════════════════════════════════╗
# ║  16. CMD+K COMMAND PALETTE                                     ║
# ╚══════════════════════════════════════════════════════════════════╝

```tsx
// components/shared/command-palette.tsx
"use client";

import { useEffect, useState, useCallback } from "react";
import { useRouter } from "next/navigation";
import { CommandDialog, CommandEmpty, CommandGroup, CommandInput, CommandItem, CommandList, CommandSeparator } from "@/components/ui/command";
import { LayoutDashboard, Users, Settings, FileText, Moon, Sun, Plus, LogOut } from "lucide-react";
import { useTheme } from "next-themes";

export function CommandPalette() {
  const [open, setOpen] = useState(false);
  const router = useRouter();
  const { setTheme, theme } = useTheme();

  useEffect(() => {
    function handleKeyDown(e: KeyboardEvent) {
      if ((e.metaKey || e.ctrlKey) && e.key === "k") { e.preventDefault(); setOpen((prev) => !prev); }
    }
    document.addEventListener("keydown", handleKeyDown);
    return () => document.removeEventListener("keydown", handleKeyDown);
  }, []);

  const navigate = useCallback((path: string) => { setOpen(false); router.push(path); }, [router]);

  return (
    <CommandDialog open={open} onOpenChange={setOpen}>
      <CommandInput placeholder="Type a command or search..." />
      <CommandList>
        <CommandEmpty>No results found.</CommandEmpty>
        <CommandGroup heading="Navigation">
          <CommandItem onSelect={() => navigate("/dashboard")}><LayoutDashboard className="mr-2 h-4 w-4" />Dashboard</CommandItem>
          <CommandItem onSelect={() => navigate("/dashboard/users")}><Users className="mr-2 h-4 w-4" />Users</CommandItem>
          <CommandItem onSelect={() => navigate("/dashboard/settings")}><Settings className="mr-2 h-4 w-4" />Settings</CommandItem>
        </CommandGroup>
        <CommandSeparator />
        <CommandGroup heading="Actions">
          <CommandItem onSelect={() => navigate("/dashboard/users/new")}><Plus className="mr-2 h-4 w-4" />Create New User</CommandItem>
          <CommandItem onSelect={() => { setTheme(theme === "dark" ? "light" : "dark"); setOpen(false); }}>
            {theme === "dark" ? <Sun className="mr-2 h-4 w-4" /> : <Moon className="mr-2 h-4 w-4" />}
            {theme === "dark" ? "Light Mode" : "Dark Mode"}
          </CommandItem>
          <CommandItem onSelect={() => navigate("/auth/signout")}><LogOut className="mr-2 h-4 w-4" />Sign Out</CommandItem>
        </CommandGroup>
      </CommandList>
    </CommandDialog>
  );
}
```


# ╔══════════════════════════════════════════════════════════════════╗
# ║  17. QUALITY CHECKLIST                                         ║
# ╚══════════════════════════════════════════════════════════════════╝
#
# Every page MUST pass this checklist before being marked complete.

```
╔══════════════════════════════════════════════════════════════════╗
║  FRONTEND PAGE QUALITY CHECKLIST                                 ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                  ║
║  Responsiveness                                                  ║
║  [ ] Tested at 320px, 768px, 1024px, 1440px, 2560px            ║
║  [ ] No horizontal scroll at any breakpoint                     ║
║                                                                  ║
║  Dark Mode                                                       ║
║  [ ] All elements use semantic tokens (bg-background, etc.)     ║
║  [ ] No white flash on initial load                             ║
║  [ ] Charts and images adapt to dark theme                      ║
║                                                                  ║
║  Loading States                                                  ║
║  [ ] Content-shaped skeleton (NEVER a spinner)                  ║
║  [ ] Skeleton matches the layout it replaces                    ║
║  [ ] loading.tsx present in route group                         ║
║                                                                  ║
║  Error States                                                    ║
║  [ ] User-friendly error message displayed                      ║
║  [ ] Retry button present and functional                        ║
║  [ ] error.tsx present in route group                           ║
║                                                                  ║
║  Empty States                                                    ║
║  [ ] Illustration or icon shown                                 ║
║  [ ] Descriptive message explains what to do                    ║
║  [ ] CTA button to create first item                            ║
║                                                                  ║
║  SEO                                                             ║
║  [ ] generateMetadata() exports title + description             ║
║  [ ] Dynamic pages use generateMetadata with fetched data       ║
║                                                                  ║
║  Accessibility                                                   ║
║  [ ] Full keyboard navigation (Tab, Enter, Escape)              ║
║  [ ] Visible focus rings on all interactive elements            ║
║  [ ] ARIA labels on icon-only buttons                           ║
║                                                                  ║
║  Forms                                                           ║
║  [ ] React Hook Form + Zod inline validation                   ║
║  [ ] Submit button shows loading state during submission        ║
║  [ ] Success toast displayed after form submission              ║
║                                                                  ║
║  Mobile                                                          ║
║  [ ] Touch targets >= 44px (h-11 minimum for buttons)           ║
║  [ ] Tables convert to card layout on mobile                    ║
║                                                                  ║
║  Route Files                                                     ║
║  [ ] page.tsx present                                           ║
║  [ ] loading.tsx present                                        ║
║  [ ] error.tsx present                                          ║
║                                                                  ║
╚══════════════════════════════════════════════════════════════════╝
```

# CODE_PATTERNS_FRONTEND_PAGES.md — Dashboard Layout + Page Templates
# Part 2 of 3: Sidebar/Header/Breadcrumbs, List/Detail/Form/Settings/Dashboard/Auth pages
# Language: TypeScript/TSX | Framework: Next.js 15+ | UI: shadcn/ui + Tailwind
# ═══════════════════════════════════════════════════════════════════
# See also: CODE_PATTERNS_FRONTEND_PRODUCTION.md (⭐ the production-ready bar — fonts & color, real data, friendly errors — READ FIRST)
#           CODE_PATTERNS_FRONTEND_CORE.md (core architecture)
#           CODE_PATTERNS_FRONTEND_UX.md (components + UX patterns)


# ╔══════════════════════════════════════════════════════════════════╗
# ║  7. DASHBOARD LAYOUT                                            ║
# ╚══════════════════════════════════════════════════════════════════╝

```tsx
// components/layouts/sidebar.tsx
"use client";

import { usePathname } from "next/navigation";
import Link from "next/link";
import { cn } from "@/lib/utils";
import {
  LayoutDashboard, Users, Settings, FileText, BarChart3, Bell, Shield,
  ChevronLeft, LogOut,
} from "lucide-react";
import { Button } from "@/components/ui/button";
import { Tooltip, TooltipContent, TooltipTrigger, TooltipProvider } from "@/components/ui/tooltip";
import { useAuth } from "@/hooks/useAuth";
import { useState } from "react";

const NAV_ITEMS = [
  { label: "Dashboard", href: "/dashboard", icon: LayoutDashboard },
  { label: "Users", href: "/dashboard/users", icon: Users },
  { label: "Reports", href: "/dashboard/reports", icon: FileText },
  { label: "Analytics", href: "/dashboard/analytics", icon: BarChart3 },
  { label: "Notifications", href: "/dashboard/notifications", icon: Bell },
  { label: "Settings", href: "/dashboard/settings", icon: Settings },
];

export function Sidebar() {
  const pathname = usePathname();
  const { user, logout } = useAuth();
  const [collapsed, setCollapsed] = useState(false);

  return (
    <TooltipProvider delayDuration={0}>
      <aside
        className={cn(
          "hidden md:flex flex-col border-r bg-card transition-all duration-300",
          collapsed ? "w-16" : "w-64"
        )}
      >
        <div className={cn("flex h-16 items-center border-b px-4", collapsed ? "justify-center" : "justify-between")}>
          {!collapsed && <span className="text-lg font-bold">APP_NAME</span>}
          <Button variant="ghost" size="icon" onClick={() => setCollapsed(!collapsed)} className="h-8 w-8">
            <ChevronLeft className={cn("h-4 w-4 transition-transform", collapsed && "rotate-180")} />
          </Button>
        </div>

        <nav className="flex-1 space-y-1 p-2">
          {NAV_ITEMS.map((item) => {
            const isActive = pathname === item.href || pathname.startsWith(`${item.href}/`);
            const link = (
              <Link
                key={item.href}
                href={item.href}
                className={cn(
                  "flex items-center gap-3 rounded-lg px-3 py-2 text-sm transition-colors",
                  isActive
                    ? "bg-primary text-primary-foreground"
                    : "text-muted-foreground hover:bg-accent hover:text-accent-foreground",
                  collapsed && "justify-center px-2"
                )}
              >
                <item.icon className="h-4 w-4 shrink-0" />
                {!collapsed && <span>{item.label}</span>}
              </Link>
            );
            if (collapsed) {
              return (
                <Tooltip key={item.href}>
                  <TooltipTrigger asChild>{link}</TooltipTrigger>
                  <TooltipContent side="right">{item.label}</TooltipContent>
                </Tooltip>
              );
            }
            return link;
          })}
        </nav>

        <div className="border-t p-2">
          <div className={cn("flex items-center gap-3 rounded-lg px-3 py-2", collapsed && "justify-center px-2")}>
            <div className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-primary text-primary-foreground text-xs font-medium">
              {user?.name?.charAt(0)?.toUpperCase() || "U"}
            </div>
            {!collapsed && (
              <div className="flex-1 truncate">
                <p className="text-sm font-medium truncate">{user?.name}</p>
                <p className="text-xs text-muted-foreground truncate">{user?.email}</p>
              </div>
            )}
          </div>
          <Button
            variant="ghost"
            className={cn("w-full mt-1", collapsed ? "justify-center px-2" : "justify-start")}
            onClick={logout}
          >
            <LogOut className="h-4 w-4 shrink-0" />
            {!collapsed && <span className="ml-2">Sign Out</span>}
          </Button>
        </div>
      </aside>
    </TooltipProvider>
  );
}
```

```tsx
// components/layouts/header.tsx
"use client";

import { Menu, Search, Bell } from "lucide-react";
import { Button } from "@/components/ui/button";
import {
  DropdownMenu, DropdownMenuContent, DropdownMenuItem,
  DropdownMenuLabel, DropdownMenuSeparator, DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar";
import { Badge } from "@/components/ui/badge";
import { ThemeToggle } from "@/components/shared/theme-toggle";
import { useAuth } from "@/hooks/useAuth";

export function Header() {
  const { user, logout } = useAuth();

  return (
    <header className="flex h-16 items-center justify-between border-b bg-card px-4 md:px-6">
      <Button variant="ghost" size="icon" className="md:hidden">
        <Menu className="h-5 w-5" />
      </Button>

      <div className="flex items-center gap-2 ml-auto">
        <Button variant="ghost" size="icon" className="hidden md:flex">
          <Search className="h-4 w-4" />
          <span className="sr-only">Search (Cmd+K)</span>
        </Button>

        <Button variant="ghost" size="icon" className="relative">
          <Bell className="h-4 w-4" />
          <Badge variant="destructive" className="absolute -right-1 -top-1 h-4 w-4 p-0 text-[10px] flex items-center justify-center">
            3
          </Badge>
        </Button>

        <ThemeToggle />

        <DropdownMenu>
          <DropdownMenuTrigger asChild>
            <Button variant="ghost" className="relative h-8 w-8 rounded-full">
              <Avatar className="h-8 w-8">
                <AvatarImage src={user?.avatar} alt={user?.name} />
                <AvatarFallback>{user?.name?.charAt(0)?.toUpperCase()}</AvatarFallback>
              </Avatar>
            </Button>
          </DropdownMenuTrigger>
          <DropdownMenuContent className="w-56" align="end">
            <DropdownMenuLabel>
              <p className="text-sm font-medium">{user?.name}</p>
              <p className="text-xs text-muted-foreground">{user?.email}</p>
            </DropdownMenuLabel>
            <DropdownMenuSeparator />
            <DropdownMenuItem asChild><a href="/dashboard/settings">Settings</a></DropdownMenuItem>
            <DropdownMenuSeparator />
            <DropdownMenuItem onClick={logout}>Sign Out</DropdownMenuItem>
          </DropdownMenuContent>
        </DropdownMenu>
      </div>
    </header>
  );
}
```

```tsx
// components/layouts/breadcrumbs.tsx
"use client";

import { usePathname } from "next/navigation";
import Link from "next/link";
import { ChevronRight, Home } from "lucide-react";

export function Breadcrumbs() {
  const pathname = usePathname();
  const segments = pathname.split("/").filter(Boolean);

  if (segments.length <= 1) return null;

  return (
    <nav className="flex items-center gap-1 text-sm text-muted-foreground mb-4">
      <Link href="/dashboard" className="hover:text-foreground"><Home className="h-4 w-4" /></Link>
      {segments.slice(1).map((segment, index) => {
        const href = "/" + segments.slice(0, index + 2).join("/");
        const isLast = index === segments.length - 2;
        const label = segment.charAt(0).toUpperCase() + segment.slice(1).replace(/-/g, " ");
        return (
          <span key={href} className="flex items-center gap-1">
            <ChevronRight className="h-3 w-3" />
            {isLast ? (
              <span className="text-foreground font-medium">{label}</span>
            ) : (
              <Link href={href} className="hover:text-foreground">{label}</Link>
            )}
          </span>
        );
      })}
    </nav>
  );
}
```


# ╔══════════════════════════════════════════════════════════════════╗
# ║  8. PAGE TEMPLATES                                              ║
# ╚══════════════════════════════════════════════════════════════════╝

### 8a. List/Table Page

```tsx
// app/(dashboard)/users/page.tsx
"use client";

import { useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { useRouter } from "next/navigation";
import { Plus, Users, Trash2, MoreHorizontal, Pencil, Eye } from "lucide-react";
import { PageHeader } from "@/components/shared/page-header";
import { PageContent } from "@/components/shared/page-content";
import { DataTable } from "@/components/shared/data-table";
import { SearchInput } from "@/components/shared/search-input";
import { ConfirmDialog } from "@/components/shared/confirm-dialog";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import {
  DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { TableSkeleton } from "@/components/shared/skeletons";
import { api } from "@/lib/api";
import { toast } from "sonner";
import { useDebounce } from "@/hooks/useDebounce";
import type { ColumnDef } from "@tanstack/react-table";

interface User {
  id: string;
  name: string;
  email: string;
  role: "user" | "admin";
  status: "active" | "inactive";
  created_at: string;
}

export default function UsersPage() {
  const router = useRouter();
  const queryClient = useQueryClient();
  const [search, setSearch] = useState("");
  const [deleteId, setDeleteId] = useState<string | null>(null);
  const debouncedSearch = useDebounce(search, 300);

  const { data, isLoading, isError, error, refetch } = useQuery<User[]>({
    queryKey: ["users", debouncedSearch],
    queryFn: () => api.get("/api/v1/users", { params: { search: debouncedSearch } }).then((r) => r.data),
  });

  const deleteMutation = useMutation({
    mutationFn: (id: string) => api.delete(`/api/v1/users/${id}`),
    onSuccess: () => {
      toast.success("User deleted");
      queryClient.invalidateQueries({ queryKey: ["users"] });
      setDeleteId(null);
    },
    onError: (err: Error) => toast.error("Failed to delete user", { description: err.message }),
  });

  const columns: ColumnDef<User>[] = [
    { accessorKey: "name", header: "Name" },
    { accessorKey: "email", header: "Email" },
    {
      accessorKey: "role",
      header: "Role",
      cell: ({ row }) => <Badge variant={row.original.role === "admin" ? "default" : "secondary"}>{row.original.role}</Badge>,
    },
    {
      accessorKey: "status",
      header: "Status",
      cell: ({ row }) => (
        <Badge variant={row.original.status === "active" ? "default" : "outline"}>{row.original.status}</Badge>
      ),
    },
    {
      id: "actions",
      cell: ({ row }) => (
        <DropdownMenu>
          <DropdownMenuTrigger asChild>
            <Button variant="ghost" size="icon"><MoreHorizontal className="h-4 w-4" /></Button>
          </DropdownMenuTrigger>
          <DropdownMenuContent align="end">
            <DropdownMenuItem onClick={() => router.push(`/dashboard/users/${row.original.id}`)}>
              <Eye className="mr-2 h-4 w-4" />View
            </DropdownMenuItem>
            <DropdownMenuItem onClick={() => router.push(`/dashboard/users/${row.original.id}/edit`)}>
              <Pencil className="mr-2 h-4 w-4" />Edit
            </DropdownMenuItem>
            <DropdownMenuItem className="text-destructive" onClick={() => setDeleteId(row.original.id)}>
              <Trash2 className="mr-2 h-4 w-4" />Delete
            </DropdownMenuItem>
          </DropdownMenuContent>
        </DropdownMenu>
      ),
    },
  ];

  return (
    <div className="flex flex-col gap-6 p-4 md:p-6">
      <PageHeader
        title="Users"
        description="Manage all registered users."
        actions={<Button onClick={() => router.push("/dashboard/users/new")}><Plus className="mr-2 h-4 w-4" />Add User</Button>}
      />
      <SearchInput value={search} onChange={setSearch} placeholder="Search users..." />
      <PageContent<User>
        isLoading={isLoading} isError={isError} error={error} data={data} onRetry={refetch}
        loadingSkeleton={<TableSkeleton rows={8} columns={5} />}
        emptyState={{
          icon: <Users className="h-12 w-12 text-muted-foreground" />,
          title: "No users found",
          description: "Get started by creating your first user.",
          actionLabel: "Add User",
          onAction: () => router.push("/dashboard/users/new"),
        }}
      >
        {(users) => <DataTable data={users as User[]} columns={columns} />}
      </PageContent>
      <ConfirmDialog
        open={!!deleteId}
        onOpenChange={(open) => !open && setDeleteId(null)}
        title="Delete User"
        description="This action cannot be undone. The user will be permanently removed."
        confirmLabel="Delete"
        variant="destructive"
        isLoading={deleteMutation.isPending}
        onConfirm={() => deleteId && deleteMutation.mutate(deleteId)}
      />
    </div>
  );
}
```

### 8b. Detail Page

```tsx
// app/(dashboard)/users/[id]/page.tsx
"use client";

import { useQuery } from "@tanstack/react-query";
import { useParams, useRouter } from "next/navigation";
import { ArrowLeft, Pencil, Trash2, MoreHorizontal } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import {
  DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { PageContent } from "@/components/shared/page-content";
import { DetailSkeleton } from "@/components/shared/skeletons";
import { api } from "@/lib/api";

export default function UserDetailPage() {
  const { id } = useParams<{ id: string }>();
  const router = useRouter();
  const { data: user, isLoading, isError, error, refetch } = useQuery({
    queryKey: ["users", id],
    queryFn: () => api.get(`/api/v1/users/${id}`).then((r) => r.data),
  });

  return (
    <div className="flex flex-col gap-6 p-4 md:p-6">
      <div className="flex items-center gap-4">
        <Button variant="ghost" size="icon" onClick={() => router.back()}>
          <ArrowLeft className="h-4 w-4" />
        </Button>
        <div className="flex-1">
          <h1 className="text-2xl font-bold">{user?.name || "User Detail"}</h1>
          <p className="text-muted-foreground">{user?.email}</p>
        </div>
        <DropdownMenu>
          <DropdownMenuTrigger asChild>
            <Button variant="outline"><MoreHorizontal className="h-4 w-4" /></Button>
          </DropdownMenuTrigger>
          <DropdownMenuContent align="end">
            <DropdownMenuItem onClick={() => router.push(`/dashboard/users/${id}/edit`)}>
              <Pencil className="mr-2 h-4 w-4" />Edit
            </DropdownMenuItem>
            <DropdownMenuItem className="text-destructive">
              <Trash2 className="mr-2 h-4 w-4" />Delete
            </DropdownMenuItem>
          </DropdownMenuContent>
        </DropdownMenu>
      </div>

      <PageContent
        isLoading={isLoading} isError={isError} error={error} data={user} onRetry={refetch}
        loadingSkeleton={<DetailSkeleton />}
        emptyState={{ icon: <></>, title: "User not found", description: "This user does not exist." }}
      >
        {(userData: any) => (
          <Tabs defaultValue="overview">
            <TabsList>
              <TabsTrigger value="overview">Overview</TabsTrigger>
              <TabsTrigger value="activity">Activity</TabsTrigger>
            </TabsList>
            <TabsContent value="overview" className="mt-4">
              <Card>
                <CardHeader><CardTitle>Profile Information</CardTitle></CardHeader>
                <CardContent className="space-y-3">
                  <div className="flex justify-between"><span className="text-muted-foreground">Name</span><span>{userData.name}</span></div>
                  <div className="flex justify-between"><span className="text-muted-foreground">Email</span><span>{userData.email}</span></div>
                  <div className="flex justify-between"><span className="text-muted-foreground">Role</span><Badge>{userData.role}</Badge></div>
                  <div className="flex justify-between"><span className="text-muted-foreground">Joined</span><span>{new Date(userData.created_at).toLocaleDateString()}</span></div>
                </CardContent>
              </Card>
            </TabsContent>
            <TabsContent value="activity" className="mt-4">
              <Card><CardContent className="p-6 text-muted-foreground text-center">Activity log coming soon.</CardContent></Card>
            </TabsContent>
          </Tabs>
        )}
      </PageContent>
    </div>
  );
}
```

### 8c. Form Page (Create/Edit)

```tsx
// app/(dashboard)/users/new/page.tsx  OR  app/(dashboard)/users/[id]/edit/page.tsx
"use client";

import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useRouter, useParams } from "next/navigation";
import { Loader2 } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import {
  Form, FormControl, FormDescription, FormField, FormItem, FormLabel, FormMessage,
} from "@/components/ui/form";
import {
  Select, SelectContent, SelectItem, SelectTrigger, SelectValue,
} from "@/components/ui/select";
import { api } from "@/lib/api";
import { toast } from "sonner";

const userSchema = z.object({
  name: z.string().min(2, "Name must be at least 2 characters"),
  email: z.string().email("Invalid email address"),
  role: z.enum(["user", "admin"]),
  bio: z.string().max(500, "Bio must be under 500 characters").optional(),
});

type UserFormValues = z.infer<typeof userSchema>;

export default function UserFormPage() {
  const router = useRouter();
  const params = useParams();
  const queryClient = useQueryClient();
  const isEdit = !!params?.id;

  const { data: existingUser } = useQuery({
    queryKey: ["users", params?.id],
    queryFn: () => api.get(`/api/v1/users/${params!.id}`).then((r) => r.data),
    enabled: isEdit,
  });

  const form = useForm<UserFormValues>({
    resolver: zodResolver(userSchema),
    defaultValues: { name: "", email: "", role: "user", bio: "" },
    values: existingUser ? { name: existingUser.name, email: existingUser.email, role: existingUser.role, bio: existingUser.bio || "" } : undefined,
  });

  const mutation = useMutation({
    mutationFn: (values: UserFormValues) =>
      isEdit ? api.patch(`/api/v1/users/${params!.id}`, values) : api.post("/api/v1/users", values),
    onSuccess: () => {
      toast.success(isEdit ? "User updated" : "User created");
      queryClient.invalidateQueries({ queryKey: ["users"] });
      router.push("/dashboard/users");
    },
    onError: (err: Error) => toast.error("Failed to save user", { description: err.message }),
  });

  return (
    <div className="flex flex-col gap-6 p-4 md:p-6 max-w-2xl">
      <Card>
        <CardHeader>
          <CardTitle>{isEdit ? "Edit User" : "Create User"}</CardTitle>
          <CardDescription>{isEdit ? "Update user information." : "Add a new user to the system."}</CardDescription>
        </CardHeader>
        <CardContent>
          <Form {...form}>
            <form onSubmit={form.handleSubmit((v) => mutation.mutate(v))} className="space-y-6">
              <FormField control={form.control} name="name" render={({ field }) => (
                <FormItem>
                  <FormLabel>Name</FormLabel>
                  <FormControl><Input placeholder="John Doe" {...field} /></FormControl>
                  <FormMessage />
                </FormItem>
              )} />
              <FormField control={form.control} name="email" render={({ field }) => (
                <FormItem>
                  <FormLabel>Email</FormLabel>
                  <FormControl><Input type="email" placeholder="john@example.com" {...field} /></FormControl>
                  <FormMessage />
                </FormItem>
              )} />
              <FormField control={form.control} name="role" render={({ field }) => (
                <FormItem>
                  <FormLabel>Role</FormLabel>
                  <Select onValueChange={field.onChange} defaultValue={field.value}>
                    <FormControl><SelectTrigger><SelectValue placeholder="Select role" /></SelectTrigger></FormControl>
                    <SelectContent>
                      <SelectItem value="user">User</SelectItem>
                      <SelectItem value="admin">Admin</SelectItem>
                    </SelectContent>
                  </Select>
                  <FormMessage />
                </FormItem>
              )} />
              <FormField control={form.control} name="bio" render={({ field }) => (
                <FormItem>
                  <FormLabel>Bio (optional)</FormLabel>
                  <FormControl><Textarea placeholder="Brief bio..." className="resize-none" {...field} /></FormControl>
                  <FormDescription>{field.value?.length ?? 0}/500 characters</FormDescription>
                  <FormMessage />
                </FormItem>
              )} />
              <div className="flex gap-4">
                <Button type="submit" disabled={mutation.isPending}>
                  {mutation.isPending && <Loader2 className="mr-2 h-4 w-4 animate-spin" />}
                  {isEdit ? "Save Changes" : "Create User"}
                </Button>
                <Button type="button" variant="outline" onClick={() => router.back()}>Cancel</Button>
              </div>
            </form>
          </Form>
        </CardContent>
      </Card>
    </div>
  );
}
```

### 8d. Settings Page

```tsx
// app/(dashboard)/settings/page.tsx
"use client";

import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import { Loader2 } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Switch } from "@/components/ui/switch";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Form, FormControl, FormDescription, FormField, FormItem, FormLabel, FormMessage } from "@/components/ui/form";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { api } from "@/lib/api";
import { toast } from "sonner";
import { useAuth } from "@/hooks/useAuth";
import { useTheme } from "next-themes";

const profileSchema = z.object({
  name: z.string().min(2, "Name is required"),
  email: z.string().email("Invalid email"),
  phone: z.string().optional(),
});

const securitySchema = z.object({
  currentPassword: z.string().min(1, "Current password is required"),
  newPassword: z.string().min(8, "Password must be at least 8 characters"),
  confirmPassword: z.string(),
}).refine((d) => d.newPassword === d.confirmPassword, { message: "Passwords do not match", path: ["confirmPassword"] });

const notificationSchema = z.object({
  emailNotifications: z.boolean(),
  pushNotifications: z.boolean(),
  weeklyDigest: z.boolean(),
  marketingEmails: z.boolean(),
});

export default function SettingsPage() {
  const { user } = useAuth();
  const { theme, setTheme } = useTheme();
  const queryClient = useQueryClient();

  const profileForm = useForm({ resolver: zodResolver(profileSchema), defaultValues: { name: user?.name ?? "", email: user?.email ?? "", phone: "" } });
  const securityForm = useForm({ resolver: zodResolver(securitySchema), defaultValues: { currentPassword: "", newPassword: "", confirmPassword: "" } });
  const notificationForm = useForm({ resolver: zodResolver(notificationSchema), defaultValues: { emailNotifications: true, pushNotifications: true, weeklyDigest: false, marketingEmails: false } });

  const profileMutation = useMutation({
    mutationFn: (values: z.infer<typeof profileSchema>) => api.patch("/api/settings/profile", values),
    onSuccess: () => { queryClient.invalidateQueries({ queryKey: ["auth", "me"] }); toast.success("Profile updated"); },
    onError: () => toast.error("Failed to update profile"),
  });

  const securityMutation = useMutation({
    mutationFn: (values: z.infer<typeof securitySchema>) => api.patch("/api/settings/password", values),
    onSuccess: () => { securityForm.reset(); toast.success("Password changed"); },
    onError: () => toast.error("Failed to change password"),
  });

  const notificationMutation = useMutation({
    mutationFn: (values: z.infer<typeof notificationSchema>) => api.patch("/api/settings/notifications", values),
    onSuccess: () => toast.success("Notification preferences saved"),
    onError: () => toast.error("Failed to save preferences"),
  });

  return (
    <div className="space-y-6 p-4 md:p-6">
      <div>
        <h1 className="text-2xl font-bold tracking-tight">Settings</h1>
        <p className="text-muted-foreground">Manage your account preferences.</p>
      </div>
      <Tabs defaultValue="profile">
        <TabsList>
          <TabsTrigger value="profile">Profile</TabsTrigger>
          <TabsTrigger value="security">Security</TabsTrigger>
          <TabsTrigger value="notifications">Notifications</TabsTrigger>
          <TabsTrigger value="appearance">Appearance</TabsTrigger>
        </TabsList>
        <TabsContent value="profile" className="mt-6">
          <Card>
            <CardHeader><CardTitle>Profile Information</CardTitle><CardDescription>Update your personal details.</CardDescription></CardHeader>
            <CardContent>
              <Form {...profileForm}>
                <form onSubmit={profileForm.handleSubmit((v) => profileMutation.mutate(v))} className="space-y-4">
                  <FormField control={profileForm.control} name="name" render={({ field }) => (<FormItem><FormLabel>Name</FormLabel><FormControl><Input {...field} /></FormControl><FormMessage /></FormItem>)} />
                  <FormField control={profileForm.control} name="email" render={({ field }) => (<FormItem><FormLabel>Email</FormLabel><FormControl><Input type="email" {...field} /></FormControl><FormMessage /></FormItem>)} />
                  <FormField control={profileForm.control} name="phone" render={({ field }) => (<FormItem><FormLabel>Phone (optional)</FormLabel><FormControl><Input type="tel" {...field} /></FormControl><FormMessage /></FormItem>)} />
                  <Button type="submit" disabled={profileMutation.isPending}>
                    {profileMutation.isPending && <Loader2 className="mr-2 h-4 w-4 animate-spin" />}Save Profile
                  </Button>
                </form>
              </Form>
            </CardContent>
          </Card>
        </TabsContent>
        <TabsContent value="security" className="mt-6">
          <Card>
            <CardHeader><CardTitle>Change Password</CardTitle></CardHeader>
            <CardContent>
              <Form {...securityForm}>
                <form onSubmit={securityForm.handleSubmit((v) => securityMutation.mutate(v))} className="space-y-4">
                  <FormField control={securityForm.control} name="currentPassword" render={({ field }) => (<FormItem><FormLabel>Current Password</FormLabel><FormControl><Input type="password" {...field} /></FormControl><FormMessage /></FormItem>)} />
                  <FormField control={securityForm.control} name="newPassword" render={({ field }) => (<FormItem><FormLabel>New Password</FormLabel><FormControl><Input type="password" {...field} /></FormControl><FormMessage /></FormItem>)} />
                  <FormField control={securityForm.control} name="confirmPassword" render={({ field }) => (<FormItem><FormLabel>Confirm Password</FormLabel><FormControl><Input type="password" {...field} /></FormControl><FormMessage /></FormItem>)} />
                  <Button type="submit" disabled={securityMutation.isPending}>
                    {securityMutation.isPending && <Loader2 className="mr-2 h-4 w-4 animate-spin" />}Change Password
                  </Button>
                </form>
              </Form>
            </CardContent>
          </Card>
        </TabsContent>
        <TabsContent value="notifications" className="mt-6">
          <Card>
            <CardHeader><CardTitle>Notification Preferences</CardTitle></CardHeader>
            <CardContent>
              <Form {...notificationForm}>
                <form onSubmit={notificationForm.handleSubmit((v) => notificationMutation.mutate(v))} className="space-y-6">
                  {(["emailNotifications", "pushNotifications", "weeklyDigest", "marketingEmails"] as const).map((name) => (
                    <FormField key={name} control={notificationForm.control} name={name} render={({ field }) => (
                      <FormItem className="flex items-center justify-between rounded-lg border p-4">
                        <div><FormLabel>{name.replace(/([A-Z])/g, " $1").trim()}</FormLabel></div>
                        <FormControl><Switch checked={field.value} onCheckedChange={field.onChange} /></FormControl>
                      </FormItem>
                    )} />
                  ))}
                  <Button type="submit" disabled={notificationMutation.isPending}>
                    {notificationMutation.isPending && <Loader2 className="mr-2 h-4 w-4 animate-spin" />}Save Preferences
                  </Button>
                </form>
              </Form>
            </CardContent>
          </Card>
        </TabsContent>
        <TabsContent value="appearance" className="mt-6">
          <Card>
            <CardHeader><CardTitle>Appearance</CardTitle></CardHeader>
            <CardContent>
              <div className="flex items-center justify-between rounded-lg border p-4">
                <div><p className="font-medium text-sm">Theme</p><p className="text-sm text-muted-foreground">Select your preferred color scheme.</p></div>
                <Select value={theme} onValueChange={setTheme}>
                  <SelectTrigger className="w-[140px]"><SelectValue /></SelectTrigger>
                  <SelectContent>
                    <SelectItem value="light">Light</SelectItem>
                    <SelectItem value="dark">Dark</SelectItem>
                    <SelectItem value="system">System</SelectItem>
                  </SelectContent>
                </Select>
              </div>
            </CardContent>
          </Card>
        </TabsContent>
      </Tabs>
    </div>
  );
}
```

### 8e. Dashboard Home Page

```tsx
// app/(dashboard)/page.tsx
"use client";

import { useQuery } from "@tanstack/react-query";
import { DollarSign, Users, ShoppingCart, TrendingUp, ArrowUpRight, ArrowDownRight } from "lucide-react";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Skeleton } from "@/components/ui/skeleton";
import { Button } from "@/components/ui/button";
import { LineChart, Line, BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer } from "recharts";
import { api } from "@/lib/api";
import { useRouter } from "next/navigation";

function StatCard({ title, value, trend, icon: Icon, loading }: { title: string; value: string; trend: number; icon: React.ElementType; loading: boolean }) {
  if (loading) {
    return (<Card><CardHeader className="flex flex-row items-center justify-between pb-2"><Skeleton className="h-4 w-24" /><Skeleton className="h-4 w-4" /></CardHeader><CardContent><Skeleton className="h-7 w-32" /><Skeleton className="mt-1 h-3 w-20" /></CardContent></Card>);
  }
  const isPositive = trend >= 0;
  return (
    <Card>
      <CardHeader className="flex flex-row items-center justify-between pb-2">
        <CardTitle className="text-sm font-medium text-muted-foreground">{title}</CardTitle>
        <Icon className="h-4 w-4 text-muted-foreground" />
      </CardHeader>
      <CardContent>
        <div className="text-2xl font-bold">{value}</div>
        <p className={`flex items-center text-xs ${isPositive ? "text-green-600" : "text-red-600"}`}>
          {isPositive ? <ArrowUpRight className="mr-1 h-3 w-3" /> : <ArrowDownRight className="mr-1 h-3 w-3" />}
          {Math.abs(trend)}% from last month
        </p>
      </CardContent>
    </Card>
  );
}

export default function DashboardHomePage() {
  const router = useRouter();
  const { data, isLoading } = useQuery({ queryKey: ["dashboard", "stats"], queryFn: () => api.get("/api/dashboard/stats").then((r) => r.data) });

  return (
    <div className="space-y-6 p-4 md:p-6">
      <div className="flex items-center justify-between">
        <div><h1 className="text-2xl font-bold tracking-tight">Dashboard</h1><p className="text-muted-foreground">Welcome back. Here is an overview.</p></div>
        <Button onClick={() => router.push("/dashboard/users/new")}>Add User</Button>
      </div>
      <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-4">
        <StatCard title="Total Users" value={data?.totalUsers?.toLocaleString() ?? "0"} trend={data?.usersTrend ?? 0} icon={Users} loading={isLoading} />
        <StatCard title="Revenue" value={data ? `$${data.revenue?.toLocaleString()}` : "$0"} trend={data?.revenueTrend ?? 0} icon={DollarSign} loading={isLoading} />
        <StatCard title="Orders" value={data?.orders?.toLocaleString() ?? "0"} trend={data?.ordersTrend ?? 0} icon={ShoppingCart} loading={isLoading} />
        <StatCard title="Conversion" value={data ? `${data.conversionRate}%` : "0%"} trend={data?.conversionTrend ?? 0} icon={TrendingUp} loading={isLoading} />
      </div>
      <div className="grid gap-4 md:grid-cols-2">
        <Card>
          <CardHeader><CardTitle>Revenue Over Time</CardTitle></CardHeader>
          <CardContent>{isLoading ? <Skeleton className="h-[300px] w-full" /> : (
            <ResponsiveContainer width="100%" height={300}>
              <LineChart data={data?.revenueChart ?? []}><CartesianGrid strokeDasharray="3 3" className="stroke-muted" /><XAxis dataKey="month" className="text-xs" /><YAxis className="text-xs" /><Tooltip /><Line type="monotone" dataKey="revenue" stroke="hsl(var(--primary))" strokeWidth={2} dot={false} /></LineChart>
            </ResponsiveContainer>
          )}</CardContent>
        </Card>
        <Card>
          <CardHeader><CardTitle>Orders by Month</CardTitle></CardHeader>
          <CardContent>{isLoading ? <Skeleton className="h-[300px] w-full" /> : (
            <ResponsiveContainer width="100%" height={300}>
              <BarChart data={data?.ordersChart ?? []}><CartesianGrid strokeDasharray="3 3" className="stroke-muted" /><XAxis dataKey="month" className="text-xs" /><YAxis className="text-xs" /><Tooltip /><Bar dataKey="orders" fill="hsl(var(--primary))" radius={[4, 4, 0, 0]} /></BarChart>
            </ResponsiveContainer>
          )}</CardContent>
        </Card>
      </div>
    </div>
  );
}
```

### 8f. Auth Pages (Login)

```tsx
// app/(auth)/login/page.tsx
"use client";

import { useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import Link from "next/link";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { Loader2 } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Checkbox } from "@/components/ui/checkbox";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Form, FormControl, FormField, FormItem, FormLabel, FormMessage } from "@/components/ui/form";
import { Alert, AlertDescription } from "@/components/ui/alert";
import { useAuth } from "@/hooks/useAuth";

const loginSchema = z.object({
  email: z.string().email("Please enter a valid email"),
  password: z.string().min(1, "Password is required"),
  rememberMe: z.boolean().optional(),
});

export default function LoginPage() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const callbackUrl = searchParams.get("callbackUrl") ?? "/dashboard";
  const { login, loginWithGoogle } = useAuth();
  const [error, setError] = useState<string | null>(null);
  const [isGoogleLoading, setIsGoogleLoading] = useState(false);

  const form = useForm<z.infer<typeof loginSchema>>({
    resolver: zodResolver(loginSchema),
    defaultValues: { email: "", password: "", rememberMe: false },
  });

  async function onSubmit(values: z.infer<typeof loginSchema>) {
    setError(null);
    try { await login(values.email, values.password, values.rememberMe); router.push(callbackUrl); }
    catch (err) { setError(err instanceof Error ? err.message : "Invalid credentials."); }
  }

  return (
    <Card className="w-full max-w-md mx-auto">
      <CardHeader className="text-center">
        <CardTitle className="text-2xl">Welcome back</CardTitle>
        <CardDescription>Sign in to your account</CardDescription>
      </CardHeader>
      <CardContent className="space-y-4">
        {error && <Alert variant="destructive"><AlertDescription>{error}</AlertDescription></Alert>}
        <Button variant="outline" className="w-full" onClick={async () => { setIsGoogleLoading(true); try { await loginWithGoogle(); router.push(callbackUrl); } catch { setError("Google sign-in failed."); } finally { setIsGoogleLoading(false); } }} disabled={isGoogleLoading}>
          {isGoogleLoading ? <Loader2 className="mr-2 h-4 w-4 animate-spin" /> : null}Continue with Google
        </Button>
        <div className="relative"><div className="absolute inset-0 flex items-center"><span className="w-full border-t" /></div><div className="relative flex justify-center text-xs uppercase"><span className="bg-card px-2 text-muted-foreground">Or</span></div></div>
        <Form {...form}>
          <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-4">
            <FormField control={form.control} name="email" render={({ field }) => (<FormItem><FormLabel>Email</FormLabel><FormControl><Input type="email" placeholder="you@example.com" {...field} /></FormControl><FormMessage /></FormItem>)} />
            <FormField control={form.control} name="password" render={({ field }) => (<FormItem><div className="flex justify-between"><FormLabel>Password</FormLabel><Link href="/forgot-password" className="text-xs text-primary hover:underline">Forgot?</Link></div><FormControl><Input type="password" {...field} /></FormControl><FormMessage /></FormItem>)} />
            <FormField control={form.control} name="rememberMe" render={({ field }) => (<FormItem className="flex items-center gap-2 space-y-0"><FormControl><Checkbox checked={field.value} onCheckedChange={field.onChange} /></FormControl><FormLabel className="text-sm font-normal">Remember me</FormLabel></FormItem>)} />
            <Button type="submit" className="w-full" disabled={form.formState.isSubmitting}>
              {form.formState.isSubmitting && <Loader2 className="mr-2 h-4 w-4 animate-spin" />}Sign In
            </Button>
          </form>
        </Form>
        <p className="text-center text-sm text-muted-foreground">No account? <Link href="/register" className="text-primary hover:underline">Sign up</Link></p>
      </CardContent>
    </Card>
  );
}
```


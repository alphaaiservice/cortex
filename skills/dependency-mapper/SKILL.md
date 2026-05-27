---
name: dependency-mapper
description: "Auto-invoked when user works on architecture planning, asks 'what depends on what', discusses coupling, needs to understand module boundaries, plans a refactor, or needs to visualize the dependency graph. Builds feature dependency graphs from codebase analysis, detects circular dependencies, identifies tightly coupled modules, maps feature -> tables -> services -> APIs -> frontend pages, and recommends decoupling strategies."
license: "Proprietary — Alpha AI Service Pvt Ltd"
compatibility: "Designed for Claude Code with cortex plugin"
metadata:
  author: "Alpha AI Service Pvt Ltd"
  version: "1.0"
---

# Dependency Mapper — Full-Stack Dependency Graph Builder

This skill builds a complete dependency map of any codebase, from database tables to frontend pages. It identifies tight coupling, circular dependencies, and suggests decoupling strategies.

---

## Step 0: Scan the Codebase

### 0a — Detect Project Structure

```
1. Identify all source directories:
   - Glob for *.py, *.ts, *.tsx, *.java, *.jsx, *.js
   - Identify backend, frontend, mobile, shared directories
   - Identify test directories

2. Identify layer boundaries:
   - Models/Entities layer (database schemas)
   - Repository/DAO layer (data access)
   - Service layer (business logic)
   - API/Controller layer (HTTP endpoints)
   - Frontend Pages layer (route-level components)
   - Frontend Components layer (shared UI)
   - Mobile Screens layer (if applicable)
```

### 0b — Extract All Modules

For each source file, extract:

```bash
# Python: Extract imports
grep -rn "^from\|^import" --include="*.py" . | grep -v __pycache__ | grep -v site-packages

# TypeScript/JavaScript: Extract imports
grep -rn "^import\|require(" --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" . | grep -v node_modules

# Java: Extract imports
grep -rn "^import " --include="*.java" . | grep -v target/

# Find all exported symbols
grep -rn "^export\|^class\|^def\|^function\|^const.*=.*=>" --include="*.py" --include="*.ts" --include="*.tsx" .
```

---

## Step 1: Build the Dependency Graph

### 1a — Database Layer (Tables)

Map all database tables and their relationships:

```
DATABASE TABLES:
+-- users
|   +-- columns: id, email, name, created_at
|   +-- foreign_keys: none
|   +-- referenced_by: orders.user_id, sessions.user_id, payments.user_id
|
+-- orders
|   +-- columns: id, user_id, status, total, created_at
|   +-- foreign_keys: user_id -> users.id
|   +-- referenced_by: order_items.order_id, payments.order_id
|
+-- order_items
|   +-- columns: id, order_id, product_id, quantity, price
|   +-- foreign_keys: order_id -> orders.id, product_id -> products.id
|   +-- referenced_by: none
```

### 1b — Service Layer (Business Logic)

Map all services and their dependencies:

```
SERVICES:
+-- UserService
|   +-- file: services/user_service.py
|   +-- depends_on: [UserRepository, EmailService, CacheService]
|   +-- depended_by: [AuthService, OrderService, AdminService]
|   +-- tables_accessed: [users, sessions]
|   +-- external_apis: none
|
+-- OrderService
|   +-- file: services/order_service.py
|   +-- depends_on: [OrderRepository, UserService, PaymentService, NotificationService]
|   +-- depended_by: [APIController, AdminService]
|   +-- tables_accessed: [orders, order_items]
|   +-- external_apis: [payment_gateway]
```

### 1c — API Layer (Endpoints)

Map all API endpoints to their service dependencies:

```
API ENDPOINTS:
+-- POST /api/auth/login
|   +-- file: api/routes/auth.py:34
|   +-- calls: AuthService.login()
|   +-- tables: users, sessions
|
+-- GET /api/orders
|   +-- file: api/routes/orders.py:12
|   +-- calls: OrderService.list_orders()
|   +-- middleware: [auth_required, rate_limit]
|   +-- tables: orders, order_items, users (join)
```

### 1d — Frontend Layer (Pages/Components)

Map all frontend pages to their API dependencies:

```
FRONTEND PAGES:
+-- /dashboard (pages/Dashboard.tsx)
|   +-- api_calls: [GET /api/dashboard/stats, GET /api/orders/recent, GET /api/notifications]
|   +-- components: [StatsCards, RecentOrders, NotificationPanel]
|   +-- shared_state: [useAuth, useNotifications]
|
+-- /orders (pages/Orders.tsx)
|   +-- api_calls: [GET /api/orders, POST /api/orders, DELETE /api/orders/:id]
|   +-- components: [OrderTable, OrderForm, OrderFilters]
|   +-- shared_state: [useAuth, useCart]
```

---

## Step 2: Detect Dependency Issues

### 2a — Circular Dependencies

Scan the import graph for cycles:

```
CIRCULAR DEPENDENCIES DETECTED:
================================

[WARNING] Cycle 1: UserService -> OrderService -> UserService
  - user_service.py imports OrderService (line 5)
  - order_service.py imports UserService (line 8)
  - Fix: Extract shared logic to a common service or use events

[WARNING] Cycle 2: auth/middleware.py -> services/user_service.py -> auth/permissions.py -> auth/middleware.py
  - 3-node cycle through auth middleware
  - Fix: Move permission checking to a separate module
```

Detection approach:

```bash
# Python: Build import graph and detect cycles
# Step 1: Extract all internal imports
grep -rn "^from app\.\|^from src\." --include="*.py" . | \
  awk -F: '{print $1 " -> " $0}' | \
  grep -v __pycache__ | grep -v test

# TypeScript: Extract all internal imports
grep -rn "from ['\"]@/\|from ['\"]\.\./" --include="*.ts" --include="*.tsx" . | \
  grep -v node_modules | grep -v ".test." | grep -v ".spec."

# Look for bidirectional imports (simple cycle detection)
# If A imports B and B imports A, that is a cycle
```

### 2b — Tight Coupling Detection

Identify modules with excessive dependencies:

```
COUPLING ANALYSIS:
==================

HIGH COUPLING (>5 direct dependencies):
  [!] OrderService depends on 7 modules
      → UserService, PaymentService, NotificationService, 
        CacheService, InventoryService, ShippingService, EmailService
      → RECOMMENDATION: Break into OrderCreationService, OrderFulfillmentService

  [!] Dashboard.tsx calls 6 different API endpoints
      → /api/stats, /api/orders, /api/users, /api/notifications, 
        /api/analytics, /api/activity
      → RECOMMENDATION: Create a /api/dashboard composite endpoint

AFFERENT COUPLING (most depended-on modules):
  UserService: 8 modules depend on it
  CacheService: 6 modules depend on it
  AuthMiddleware: 5 modules depend on it
  → These are CORE modules — changes here have maximum blast radius

EFFERENT COUPLING (most dependent modules):
  OrderService: depends on 7 modules
  AdminService: depends on 6 modules
  → These are FRAGILE modules — likely to break when other things change
```

### 2c — Layer Violation Detection

Check for architectural violations:

```
LAYER VIOLATIONS:
=================

[ERROR] API layer directly accesses database (bypasses service layer)
  → api/routes/admin.py:45 — uses db.execute() directly
  → Fix: Move query to AdminRepository, call via AdminService

[ERROR] Frontend component imports backend model
  → components/UserCard.tsx:3 — imports from '../../../backend/models'
  → Fix: Use API response types defined in frontend

[WARNING] Service layer imports from API layer
  → services/webhook_service.py:12 — imports from api/schemas
  → Fix: Define shared types in a common module

[WARNING] Repository layer contains business logic
  → repositories/order_repo.py:67 — calculates discount (should be in service)
  → Fix: Move discount calculation to OrderService
```

---

## Step 3: Generate Dependency Map Visualization

Output the complete dependency map in a readable format:

```
FULL-STACK DEPENDENCY MAP
=========================

Layer 1: DATABASE
  users ←──── orders ←──── order_items
    ↑            ↑              ↑
    |            |              |
    ↓            ↓              ↓

Layer 2: REPOSITORIES
  UserRepo     OrderRepo     ProductRepo
    ↑            ↑              ↑
    |            |              |
    ↓            ↓              ↓

Layer 3: SERVICES
  UserService ←→ OrderService → PaymentService
       ↑              ↑              ↑
       |              |              |
       ↓              ↓              ↓

Layer 4: API ROUTES
  /api/users    /api/orders    /api/payments
       ↑              ↑              ↑
       |              |              |
       ↓              ↓              ↓

Layer 5: FRONTEND PAGES
  /profile      /orders        /billing
  /admin        /dashboard

LEGEND:
  → = depends on (imports/calls)
  ←→ = bidirectional dependency (potential issue)
  ← = is depended on by
```

---

## Step 4: Decoupling Recommendations

Based on the analysis, provide specific decoupling strategies:

### Strategy 1: Event-Driven Decoupling

When services are tightly coupled through direct calls:

```python
# BEFORE: Tight coupling
class OrderService:
    def __init__(self, user_svc, payment_svc, email_svc, inventory_svc, shipping_svc):
        self.user_svc = user_svc
        self.payment_svc = payment_svc
        self.email_svc = email_svc
        self.inventory_svc = inventory_svc
        self.shipping_svc = shipping_svc

    async def create_order(self, data):
        user = await self.user_svc.get(data.user_id)
        payment = await self.payment_svc.charge(data.amount)
        await self.inventory_svc.reserve(data.items)
        await self.shipping_svc.schedule(data)
        await self.email_svc.send_confirmation(user.email, data)

# AFTER: Event-driven decoupling
class OrderService:
    def __init__(self, order_repo, event_bus):
        self.order_repo = order_repo
        self.event_bus = event_bus

    async def create_order(self, data):
        order = await self.order_repo.create(data)
        await self.event_bus.publish("order.created", {
            "order_id": order.id,
            "user_id": data.user_id,
            "items": data.items,
            "amount": data.amount,
        })
        return order

# Each service subscribes to events independently
# PaymentService listens for "order.created" -> charges payment
# InventoryService listens for "order.created" -> reserves stock
# EmailService listens for "order.created" -> sends confirmation
# ShippingService listens for "payment.completed" -> schedules shipping
```

### Strategy 2: Interface Segregation

When a module exposes too many methods:

```python
# BEFORE: Fat interface
class UserService:
    def get_user(self, id): ...
    def create_user(self, data): ...
    def update_user(self, id, data): ...
    def delete_user(self, id): ...
    def get_user_stats(self, id): ...
    def get_user_orders(self, id): ...
    def get_user_payments(self, id): ...
    def get_user_sessions(self, id): ...

# AFTER: Segregated interfaces
class UserQueryService:       # For read-only consumers
    def get_user(self, id): ...
    def get_user_stats(self, id): ...

class UserCommandService:     # For write operations
    def create_user(self, data): ...
    def update_user(self, id, data): ...
    def delete_user(self, id): ...
```

### Strategy 3: Composite API Endpoints

When frontend makes too many API calls:

```python
# BEFORE: Frontend makes 6 API calls for dashboard
# GET /api/stats
# GET /api/orders/recent
# GET /api/notifications
# GET /api/analytics
# GET /api/users/me
# GET /api/activity

# AFTER: Single composite endpoint
@router.get("/api/dashboard")
async def get_dashboard(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    stats, orders, notifications, analytics, activity = await asyncio.gather(
        stats_service.get_summary(user.id),
        order_service.get_recent(user.id, limit=5),
        notification_service.get_unread(user.id, limit=10),
        analytics_service.get_user_analytics(user.id),
        activity_service.get_recent(user.id, limit=20),
    )
    return {
        "user": UserSummary.from_orm(user),
        "stats": stats,
        "recent_orders": orders,
        "notifications": notifications,
        "analytics": analytics,
        "activity": activity,
    }
```

---

## Step 5: Cascading Change Warnings

For any proposed change, warn about cascade effects:

```
CASCADE ANALYSIS: Renaming 'users.email' to 'users.email_address'
================================================================

DIRECT IMPACT (must change):
  [1] models/user.py — Column definition
  [2] repositories/user_repo.py — 3 queries reference 'email'
  [3] services/user_service.py — 5 methods reference 'email'
  [4] services/auth_service.py — login_by_email() method
  [5] services/email_service.py — get_recipient_email()
  [6] api/schemas/user.py — UserResponse.email field
  [7] api/routes/auth.py — login endpoint request body
  [8] alembic migration — rename column migration

INDIRECT IMPACT (may need change):
  [9] frontend/src/types/user.ts — User interface
  [10] frontend/src/pages/Profile.tsx — displays email
  [11] frontend/src/pages/Settings.tsx — edit email form
  [12] frontend/src/components/UserCard.tsx — shows email
  [13] mobile/src/screens/Profile.tsx — displays email
  [14] tests/test_user_service.py — 8 tests reference email
  [15] tests/test_auth.py — 3 tests reference email

EXTERNAL IMPACT (notify consumers):
  [16] API documentation — response schema changed
  [17] Webhook payloads — user.email field renamed
  [18] Third-party integrations — any system reading user data

TOTAL: 18 files, 3 external systems
ESTIMATED EFFORT: 2-4 hours (code) + notification time
```

---

## Step 6: Output Summary

```
+================================================================+
|  DEPENDENCY MAP COMPLETE                                        |
+================================================================+
|                                                                 |
|  Modules Analyzed: [X] files across [Y] directories             |
|                                                                 |
|  Dependency Stats:                                              |
|  +-- Database Tables: [X]                                       |
|  +-- Services: [X]                                              |
|  +-- API Endpoints: [X]                                         |
|  +-- Frontend Pages: [X]                                        |
|  +-- Total Dependencies: [X]                                    |
|                                                                 |
|  Issues Found:                                                  |
|  +-- Circular Dependencies: [X]                                 |
|  +-- Tightly Coupled Modules: [X]                               |
|  +-- Layer Violations: [X]                                      |
|                                                                 |
|  Top Recommendations:                                           |
|  1. [Most impactful decoupling action]                          |
|  2. [Second most impactful]                                     |
|  3. [Third most impactful]                                      |
+================================================================+
```

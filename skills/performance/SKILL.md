---
name: performance
description: "Auto-invoked when writing database queries, API endpoints, caching logic, or any performance-sensitive code. Enforces performance best practices and prevents common bottlenecks."
---

# Performance Standards

This skill enforces performance best practices across all Alpha AI applications. Every database query, API endpoint, caching implementation, and frontend component MUST comply with these standards to prevent bottlenecks and ensure responsive user experiences.

---

## 1. Database Performance

### 1.1 Indexing Rules
- ALWAYS add indexes on: foreign keys, WHERE clause columns, ORDER BY columns, JOIN columns
- Use composite indexes for queries filtering on multiple columns (leftmost prefix rule)
- Use partial indexes for filtered queries on large tables
- Review index usage periodically; drop unused indexes
- NEVER add indexes blindly -- check EXPLAIN output first
```python
# REQUIRED: Index definitions in SQLAlchemy models
from sqlalchemy import Column, Integer, String, DateTime, Index, ForeignKey

class Order(Base):
    __tablename__ = "orders"

    id = Column(Integer, primary_key=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    status = Column(String(20), nullable=False, index=True)
    created_at = Column(DateTime, nullable=False, index=True)
    total_amount = Column(Integer, nullable=False)

    # Composite index for common query patterns
    __table_args__ = (
        Index("ix_orders_user_status", "user_id", "status"),
        Index("ix_orders_status_created", "status", "created_at"),
        # Partial index for active orders only
        Index("ix_orders_active", "user_id", "created_at",
              postgresql_where=Column("status") != "cancelled"),
    )
```

### 1.2 Query Rules
- NEVER use `SELECT *` -- always specify the exact columns needed
- Use column projection to reduce data transfer
- For aggregate queries, use database-level aggregation (not Python-level)
```python
# WRONG: Select all columns
users = await db.execute(select(User))

# CORRECT: Select only needed columns
users = await db.execute(
    select(User.id, User.email, User.name)
    .where(User.is_active == True)
)

# WRONG: Python-level aggregation
all_orders = await db.execute(select(Order))
total = sum(o.amount for o in all_orders.scalars())

# CORRECT: Database-level aggregation
from sqlalchemy import func
result = await db.execute(
    select(func.sum(Order.amount))
    .where(Order.user_id == user_id)
)
total = result.scalar()
```

### 1.3 Pagination
- ALL list endpoints MUST use pagination
- Use cursor-based pagination for large datasets (more efficient than OFFSET)
- Use LIMIT + OFFSET for small, stable datasets
- Default page size: 20, Maximum page size: 100
```python
# REQUIRED: Cursor-based pagination pattern
from datetime import datetime
from typing import Optional
from pydantic import BaseModel, Field

class PaginationParams(BaseModel):
    cursor: Optional[str] = None  # Base64-encoded cursor
    limit: int = Field(default=20, ge=1, le=100)

class PaginatedResponse(BaseModel):
    items: list
    next_cursor: Optional[str] = None
    has_more: bool = False

async def get_orders_paginated(
    db: AsyncSession,
    user_id: int,
    params: PaginationParams,
) -> PaginatedResponse:
    query = (
        select(Order)
        .where(Order.user_id == user_id)
        .order_by(Order.created_at.desc(), Order.id.desc())
        .limit(params.limit + 1)  # Fetch one extra to detect has_more
    )

    if params.cursor:
        cursor_data = decode_cursor(params.cursor)
        query = query.where(
            (Order.created_at < cursor_data["created_at"]) |
            (
                (Order.created_at == cursor_data["created_at"]) &
                (Order.id < cursor_data["id"])
            )
        )

    result = await db.execute(query)
    items = list(result.scalars().all())

    has_more = len(items) > params.limit
    if has_more:
        items = items[:params.limit]

    next_cursor = None
    if has_more and items:
        last = items[-1]
        next_cursor = encode_cursor({"created_at": last.created_at, "id": last.id})

    return PaginatedResponse(items=items, next_cursor=next_cursor, has_more=has_more)
```

### 1.4 N+1 Query Prevention
- ALWAYS use eager loading for relationships that will be accessed
- Use `joinedload` for one-to-one and many-to-one relationships
- Use `selectinload` for one-to-many and many-to-many relationships
- NEVER access relationship attributes inside a loop without eager loading
```python
# WRONG: N+1 query (1 query for users + N queries for orders)
users = await db.execute(select(User).limit(20))
for user in users.scalars():
    print(user.orders)  # Each access triggers a separate query!

# CORRECT: Eager loading with selectinload
from sqlalchemy.orm import selectinload, joinedload

users = await db.execute(
    select(User)
    .options(selectinload(User.orders))  # One-to-many: use selectinload
    .options(joinedload(User.profile))   # One-to-one: use joinedload
    .limit(20)
)

# CORRECT: For complex nested relationships
users = await db.execute(
    select(User)
    .options(
        selectinload(User.orders).selectinload(Order.items),
        joinedload(User.profile),
    )
    .limit(20)
)
```

### 1.5 Connection Pooling
- ALWAYS configure connection pooling for database connections
- Production settings: pool_size=20, max_overflow=10
- Set pool_recycle to prevent stale connections (1800 seconds)
- Set pool_pre_ping=True for connection health checking
```python
# REQUIRED: Database engine configuration
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy.orm import sessionmaker

engine = create_async_engine(
    settings.DATABASE_URL,
    pool_size=20,           # Base pool connections
    max_overflow=10,        # Extra connections under load
    pool_recycle=1800,      # Recycle connections after 30 min
    pool_pre_ping=True,     # Check connection health before use
    pool_timeout=30,        # Wait max 30s for a connection
    echo=False,             # NEVER True in production
)

async_session = sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)
```

### 1.6 Query Analysis
- For complex queries, ALWAYS check the EXPLAIN plan before shipping
- Watch for: sequential scans on large tables, high cost estimates, missing indexes
- Use `EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON)` for detailed analysis
```python
# Development helper: Query analysis
async def explain_query(db: AsyncSession, query):
    """Run EXPLAIN ANALYZE on a query during development."""
    from sqlalchemy import text
    explain_stmt = text(f"EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON) {query}")
    result = await db.execute(explain_stmt)
    return result.scalar()
```

### 1.7 Read Replicas
- Use read replicas for heavy read operations (reports, analytics, search)
- Route writes to primary, reads to replica
- Account for replication lag (eventual consistency) in application logic
```python
# REQUIRED: Read replica routing
from sqlalchemy.ext.asyncio import create_async_engine

write_engine = create_async_engine(settings.DATABASE_URL, pool_size=20)
read_engine = create_async_engine(settings.DATABASE_READ_REPLICA_URL, pool_size=30)

# Use write_engine for mutations
async def create_order(order_data):
    async with AsyncSession(write_engine) as session:
        ...

# Use read_engine for queries
async def get_orders(user_id: int):
    async with AsyncSession(read_engine) as session:
        ...
```

### 1.8 Batch Operations
- Use bulk inserts for creating multiple records
- Use bulk updates for mass updates
- Batch size: 1000 records per batch (tune based on row size)
```python
# REQUIRED: Batch insert pattern
async def bulk_create_orders(db: AsyncSession, orders: list[dict]):
    BATCH_SIZE = 1000
    for i in range(0, len(orders), BATCH_SIZE):
        batch = orders[i:i + BATCH_SIZE]
        await db.execute(Order.__table__.insert(), batch)
    await db.commit()

# REQUIRED: Batch update pattern
from sqlalchemy import update

async def bulk_update_status(db: AsyncSession, order_ids: list[int], new_status: str):
    await db.execute(
        update(Order)
        .where(Order.id.in_(order_ids))
        .values(status=new_status)
    )
    await db.commit()
```

---

## 2. API Performance

### 2.1 Async Endpoints
- ALL endpoints performing I/O MUST use `async def` with `await`
- NEVER use synchronous I/O in async endpoints (blocks the event loop)
- Use `run_in_executor` only as a last resort for legacy sync libraries
```python
# WRONG: Sync function for I/O endpoint
@app.get("/users")
def get_users(db: Session = Depends(get_db)):  # Blocks event loop!
    return db.query(User).all()

# CORRECT: Async endpoint
@app.get("/users")
async def get_users(db: AsyncSession = Depends(get_async_db)):
    result = await db.execute(select(User).limit(20))
    return result.scalars().all()
```

### 2.2 Response Time Targets
- p50 < 200ms for standard API calls
- p95 < 500ms for standard API calls
- p99 < 1000ms for standard API calls
- p95 < 2000ms for complex aggregation endpoints
- Monitor and alert when targets are breached

### 2.3 Background Tasks
- Use FastAPI's BackgroundTasks for non-blocking operations
- Use Celery/RQ for long-running tasks (>30 seconds)
- NEVER make the client wait for operations that can be deferred
```python
# REQUIRED: Background task pattern
from fastapi import BackgroundTasks

@app.post("/users")
async def create_user(
    user_data: UserCreate,
    background_tasks: BackgroundTasks,
    db: AsyncSession = Depends(get_async_db),
):
    user = await create_user_in_db(db, user_data)

    # These don't block the response
    background_tasks.add_task(send_welcome_email, user.email)
    background_tasks.add_task(log_user_creation, user.id)
    background_tasks.add_task(sync_to_analytics, user)

    return user

# For long-running tasks, use Celery
from celery import shared_task

@shared_task(bind=True, max_retries=3, default_retry_delay=60)
def generate_report(self, report_id: int):
    """This runs in a separate worker process."""
    try:
        # Long-running report generation
        ...
    except Exception as exc:
        self.retry(exc=exc)
```

### 2.4 Response Compression
- Enable gzip compression for responses larger than 1KB
- Set appropriate compression level (6 for balance of speed/ratio)
```python
# REQUIRED: Compression middleware
from fastapi.middleware.gzip import GZipMiddleware

app.add_middleware(GZipMiddleware, minimum_size=1000)  # Compress responses > 1KB
```

### 2.5 Cache-Control Headers
- Set `Cache-Control` headers on all responses
- Static assets: `max-age=31536000, immutable` (1 year, content-hashed filenames)
- API responses: `no-cache` or short `max-age` based on freshness requirements
- Private user data: `private, no-store`
```python
# REQUIRED: Cache-Control headers
from fastapi import Response

@app.get("/api/v1/config")
async def get_config(response: Response):
    response.headers["Cache-Control"] = "public, max-age=3600"  # 1 hour
    return {"version": "1.0", "features": [...]}

@app.get("/api/v1/users/me")
async def get_current_user(response: Response, user: User = Depends(get_current_user)):
    response.headers["Cache-Control"] = "private, no-store"
    return user
```

### 2.6 ETags for Conditional Requests
- Use ETags for resources that clients may cache
- Return 304 Not Modified when content has not changed
- Reduces bandwidth and improves perceived performance
```python
# REQUIRED: ETag pattern
import hashlib

@app.get("/api/v1/products/{product_id}")
async def get_product(product_id: int, request: Request, db: AsyncSession = Depends(get_async_db)):
    product = await get_product_by_id(db, product_id)

    etag = hashlib.md5(f"{product.id}:{product.updated_at}".encode()).hexdigest()

    if request.headers.get("if-none-match") == etag:
        return Response(status_code=304)

    response = JSONResponse(content=product.dict())
    response.headers["ETag"] = etag
    response.headers["Cache-Control"] = "public, max-age=60"
    return response
```

### 2.7 Response Payload Optimization
- Limit response payload size with pagination (see Section 1.3)
- Support field selection (sparse fieldsets) for large responses
- Use response models to exclude internal fields
```python
# REQUIRED: Response model pattern
from pydantic import BaseModel

class UserSummary(BaseModel):
    """Lightweight response model for list endpoints."""
    id: int
    name: str
    email: str

class UserDetail(BaseModel):
    """Full response model for detail endpoints."""
    id: int
    name: str
    email: str
    created_at: datetime
    profile: ProfileResponse
    preferences: dict

@app.get("/api/v1/users", response_model=list[UserSummary])
async def list_users():
    ...  # Returns only id, name, email

@app.get("/api/v1/users/{user_id}", response_model=UserDetail)
async def get_user(user_id: int):
    ...  # Returns full user detail
```

---

## 3. Caching Strategy (Redis)

### 3.1 What to Cache
- Frequently read, rarely written data (configuration, feature flags)
- Expensive computations (aggregated reports, analytics)
- External API responses (third-party data with acceptable staleness)
- Session data and rate limiting counters
- NEVER cache: authentication tokens, passwords, PII without encryption

### 3.2 TTL Guidelines
- User-specific data: 5 minutes TTL
- Public/shared data: 1 hour TTL
- Static reference data: 24 hours TTL
- Computed aggregations: 15 minutes TTL
- External API responses: match the API's cache headers or 5 minutes default
```python
# REQUIRED: TTL constants
class CacheTTL:
    USER_DATA = 300          # 5 minutes
    PUBLIC_DATA = 3600       # 1 hour
    STATIC_DATA = 86400      # 24 hours
    AGGREGATION = 900        # 15 minutes
    EXTERNAL_API = 300       # 5 minutes
    SESSION = 1800           # 30 minutes
```

### 3.3 Cache-Aside Pattern (Read-Through)
- Check cache first
- On miss: query database, store in cache, return result
- On hit: return cached result directly
```python
# REQUIRED: Cache-aside pattern
import json
from redis.asyncio import Redis

redis = Redis.from_url(settings.REDIS_URL, decode_responses=True)

async def get_user_profile(user_id: int, db: AsyncSession) -> dict:
    cache_key = f"user:profile:{user_id}"

    # 1. Check cache
    cached = await redis.get(cache_key)
    if cached:
        return json.loads(cached)

    # 2. Cache miss: query database
    result = await db.execute(
        select(User)
        .options(joinedload(User.profile))
        .where(User.id == user_id)
    )
    user = result.scalar_one_or_none()
    if not user:
        return None

    # 3. Store in cache
    user_data = UserProfile.from_orm(user).dict()
    await redis.setex(cache_key, CacheTTL.USER_DATA, json.dumps(user_data, default=str))

    return user_data
```

### 3.4 Cache Invalidation
- Invalidate on write: DELETE the cache key when the source data changes
- NEVER update cache values directly (delete + let next read repopulate)
- Use cache key patterns for bulk invalidation
```python
# REQUIRED: Cache invalidation on write
async def update_user_profile(user_id: int, data: dict, db: AsyncSession):
    # 1. Update database
    await db.execute(
        update(User).where(User.id == user_id).values(**data)
    )
    await db.commit()

    # 2. Invalidate cache (delete, don't update)
    await redis.delete(f"user:profile:{user_id}")

    # 3. Invalidate related caches
    await redis.delete(f"user:settings:{user_id}")

# Bulk invalidation pattern
async def invalidate_user_caches(user_id: int):
    """Invalidate all caches related to a user."""
    keys = [
        f"user:profile:{user_id}",
        f"user:settings:{user_id}",
        f"user:orders:{user_id}:*",
    ]
    # Use scan for pattern-based deletion
    async for key in redis.scan_iter(f"user:*:{user_id}:*"):
        await redis.delete(key)
    for key in keys[:2]:  # Direct keys
        await redis.delete(key)
```

### 3.5 Cache Key Naming Convention
- Format: `{entity}:{id}` for single records
- Format: `{entity}:list:{page}:{filters_hash}` for paginated lists
- Format: `{entity}:count:{filters_hash}` for counts
- Use consistent naming across the entire application
```python
# REQUIRED: Cache key generation
import hashlib
import json

def cache_key_single(entity: str, entity_id: int) -> str:
    return f"{entity}:{entity_id}"

def cache_key_list(entity: str, page: int, filters: dict) -> str:
    filters_hash = hashlib.md5(json.dumps(filters, sort_keys=True).encode()).hexdigest()[:8]
    return f"{entity}:list:{page}:{filters_hash}"

def cache_key_count(entity: str, filters: dict) -> str:
    filters_hash = hashlib.md5(json.dumps(filters, sort_keys=True).encode()).hexdigest()[:8]
    return f"{entity}:count:{filters_hash}"

# Examples:
# cache_key_single("user", 123)            -> "user:123"
# cache_key_list("order", 1, {"status": "active"}) -> "order:list:1:a1b2c3d4"
# cache_key_count("order", {"status": "active"})   -> "order:count:a1b2c3d4"
```

### 3.6 Cache Monitoring
- Monitor hit/miss ratio (target: >80% hit rate)
- Monitor cache memory usage
- Monitor eviction rate
- Alert when hit rate drops below 70%
```python
# REQUIRED: Cache metrics tracking
from prometheus_client import Counter, Histogram

cache_hits = Counter("cache_hits_total", "Cache hit count", ["entity"])
cache_misses = Counter("cache_misses_total", "Cache miss count", ["entity"])
cache_latency = Histogram("cache_operation_seconds", "Cache operation latency", ["operation"])

async def get_cached(key: str, entity: str) -> Optional[str]:
    with cache_latency.labels(operation="get").time():
        result = await redis.get(key)
    if result:
        cache_hits.labels(entity=entity).inc()
    else:
        cache_misses.labels(entity=entity).inc()
    return result
```

---

## 4. Frontend Performance

### 4.1 Code Splitting & Lazy Loading
- Lazy load ALL route-level components
- Lazy load heavy components that are below the fold
- Use Suspense with meaningful loading states
```typescript
// REQUIRED: Route-level lazy loading
import { lazy, Suspense } from "react";
import { Routes, Route } from "react-router-dom";

const Dashboard = lazy(() => import("./pages/Dashboard"));
const Settings = lazy(() => import("./pages/Settings"));
const Analytics = lazy(() => import("./pages/Analytics"));
const UserProfile = lazy(() => import("./pages/UserProfile"));

function AppRoutes() {
  return (
    <Suspense fallback={<PageSkeleton />}>
      <Routes>
        <Route path="/dashboard" element={<Dashboard />} />
        <Route path="/settings" element={<Settings />} />
        <Route path="/analytics" element={<Analytics />} />
        <Route path="/profile" element={<UserProfile />} />
      </Routes>
    </Suspense>
  );
}

// REQUIRED: Component-level lazy loading for heavy below-fold content
const HeavyChart = lazy(() => import("./components/HeavyChart"));
const DataTable = lazy(() => import("./components/DataTable"));

function DashboardPage() {
  return (
    <div>
      <DashboardHeader />  {/* Critical: loaded eagerly */}
      <KPICards />          {/* Critical: loaded eagerly */}
      <Suspense fallback={<ChartSkeleton />}>
        <HeavyChart />      {/* Below fold: lazy loaded */}
      </Suspense>
      <Suspense fallback={<TableSkeleton />}>
        <DataTable />       {/* Below fold: lazy loaded */}
      </Suspense>
    </div>
  );
}
```

### 4.2 Image Optimization
- Use `next/image` (Next.js) or responsive image components
- Serve images in WebP format with JPEG/PNG fallbacks
- Set explicit width and height to prevent layout shift
- Use `loading="lazy"` for below-fold images
- Generate responsive srcsets for different viewport widths
```typescript
// REQUIRED: Image optimization pattern (Next.js)
import Image from "next/image";

function ProductCard({ product }: { product: Product }) {
  return (
    <Image
      src={product.imageUrl}
      alt={product.name}
      width={400}
      height={300}
      loading="lazy"
      placeholder="blur"
      blurDataURL={product.blurHash}
      sizes="(max-width: 768px) 100vw, (max-width: 1200px) 50vw, 33vw"
    />
  );
}
```

### 4.3 Data Fetching (React Query / TanStack Query)
- Use React Query for ALL server state management
- Configure appropriate stale times and cache times
- Prefetch data for likely next navigation
- Use optimistic updates for better perceived performance
```typescript
// REQUIRED: React Query configuration
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";

const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 5 * 60 * 1000,     // 5 minutes
      gcTime: 30 * 60 * 1000,       // 30 minutes (formerly cacheTime)
      retry: 2,
      refetchOnWindowFocus: false,
    },
  },
});

// REQUIRED: Prefetching for navigation
function UserList() {
  const queryClient = useQueryClient();

  const handleMouseEnter = (userId: number) => {
    queryClient.prefetchQuery({
      queryKey: ["user", userId],
      queryFn: () => fetchUser(userId),
      staleTime: 5 * 60 * 1000,
    });
  };

  return users.map((user) => (
    <Link
      key={user.id}
      to={`/users/${user.id}`}
      onMouseEnter={() => handleMouseEnter(user.id)}
    >
      {user.name}
    </Link>
  ));
}

// REQUIRED: Optimistic updates
function useUpdateUser() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: updateUser,
    onMutate: async (newData) => {
      await queryClient.cancelQueries({ queryKey: ["user", newData.id] });
      const previous = queryClient.getQueryData(["user", newData.id]);
      queryClient.setQueryData(["user", newData.id], (old) => ({
        ...old,
        ...newData,
      }));
      return { previous };
    },
    onError: (err, newData, context) => {
      queryClient.setQueryData(["user", newData.id], context.previous);
    },
    onSettled: (data, err, newData) => {
      queryClient.invalidateQueries({ queryKey: ["user", newData.id] });
    },
  });
}
```

### 4.4 Input Debouncing
- Debounce ALL search inputs: 300ms minimum
- Debounce resize handlers: 150ms
- Debounce scroll handlers: 100ms (or use IntersectionObserver)
- Throttle (not debounce) for continuous events like drag
```typescript
// REQUIRED: Search input debouncing
import { useState, useMemo } from "react";
import { useDebouncedCallback } from "use-debounce";

function SearchInput({ onSearch }: { onSearch: (query: string) => void }) {
  const [value, setValue] = useState("");

  const debouncedSearch = useDebouncedCallback((query: string) => {
    onSearch(query);
  }, 300);

  return (
    <input
      value={value}
      onChange={(e) => {
        setValue(e.target.value);
        debouncedSearch(e.target.value);
      }}
      placeholder="Search..."
    />
  );
}
```

### 4.5 Virtual Scrolling
- Use virtual scrolling for lists with more than 100 items
- Use `react-window` or `@tanstack/react-virtual` for implementation
- Maintain consistent row heights for optimal performance
```typescript
// REQUIRED: Virtual scrolling for long lists
import { FixedSizeList as List } from "react-window";

function VirtualizedOrderList({ orders }: { orders: Order[] }) {
  const Row = ({ index, style }: { index: number; style: React.CSSProperties }) => (
    <div style={style}>
      <OrderRow order={orders[index]} />
    </div>
  );

  return (
    <List
      height={600}
      itemCount={orders.length}
      itemSize={72}       // Fixed row height for performance
      width="100%"
      overscanCount={5}   // Render 5 extra items above/below viewport
    >
      {Row}
    </List>
  );
}
```

### 4.6 Core Web Vitals Targets
- **LCP (Largest Contentful Paint)**: < 2.5 seconds
- **FID (First Input Delay)**: < 100 milliseconds
- **CLS (Cumulative Layout Shift)**: < 0.1
- **INP (Interaction to Next Paint)**: < 200 milliseconds
- **TTFB (Time to First Byte)**: < 800 milliseconds

### 4.7 Bundle Size Management
- Monitor bundle size in CI (fail if main bundle > 250KB gzipped)
- Use dynamic imports for route-level code splitting
- Analyze bundles regularly with `webpack-bundle-analyzer` or `@next/bundle-analyzer`
- Tree-shake unused exports (ensure ESM imports)
```typescript
// REQUIRED: Dynamic import for heavy libraries
// WRONG: Import entire library
import _ from "lodash";  // Imports 70KB+

// CORRECT: Import specific functions
import debounce from "lodash/debounce";

// CORRECT: Use native alternatives when possible
const unique = [...new Set(array)];  // Instead of _.uniq
const grouped = Object.groupBy(array, (item) => item.category);  // Instead of _.groupBy
```

---

## 5. Async Best Practices (Python)

### 5.1 Never Block the Event Loop
- NEVER use synchronous I/O in async endpoints
- NEVER use `time.sleep()` in async code (use `asyncio.sleep()`)
- NEVER use `requests` library in async code (use `httpx`)
- NEVER use synchronous file I/O (use `aiofiles`)
```python
# WRONG: Blocking the event loop
import requests
import time

@app.get("/data")
async def get_data():
    time.sleep(1)  # BLOCKS entire event loop!
    response = requests.get("https://api.example.com/data")  # BLOCKS!
    return response.json()

# CORRECT: Non-blocking async
import httpx
import asyncio

@app.get("/data")
async def get_data():
    await asyncio.sleep(1)  # Non-blocking
    async with httpx.AsyncClient() as client:
        response = await client.get("https://api.example.com/data")  # Non-blocking
    return response.json()
```

### 5.2 Async Database Drivers
- Use `asyncpg` or `asyncmy` for async database access
- Use `redis.asyncio` for async Redis (NOT synchronous `redis`)
- Configure connection pools at application startup
```python
# REQUIRED: Async Redis client
from redis.asyncio import Redis

redis = Redis.from_url(
    settings.REDIS_URL,
    encoding="utf-8",
    decode_responses=True,
    max_connections=50,
)

# Startup and shutdown
@app.on_event("startup")
async def startup():
    await redis.ping()

@app.on_event("shutdown")
async def shutdown():
    await redis.close()
```

### 5.3 HTTP Client Best Practices
- Use `httpx.AsyncClient` for ALL external HTTP calls
- Create a shared client instance on startup (connection pooling)
- Set timeouts on ALL external calls
- Use connection pooling limits
```python
# REQUIRED: Shared async HTTP client
import httpx

# Create on startup, close on shutdown
http_client: httpx.AsyncClient = None

@app.on_event("startup")
async def startup():
    global http_client
    http_client = httpx.AsyncClient(
        timeout=httpx.Timeout(
            connect=5.0,     # Connection timeout
            read=30.0,       # Read timeout
            write=10.0,      # Write timeout
            pool=10.0,       # Pool timeout
        ),
        limits=httpx.Limits(
            max_connections=100,
            max_keepalive_connections=20,
        ),
        follow_redirects=True,
    )

@app.on_event("shutdown")
async def shutdown():
    if http_client:
        await http_client.aclose()
```

### 5.4 Parallel I/O with asyncio.gather
- Use `asyncio.gather()` for independent I/O operations that can run concurrently
- Use `return_exceptions=True` to prevent one failure from canceling all tasks
- Set individual timeouts on each task when appropriate
```python
# REQUIRED: Parallel I/O pattern
import asyncio

async def get_dashboard_data(user_id: int) -> dict:
    """Fetch all dashboard data in parallel instead of sequentially."""

    # WRONG: Sequential (total time = sum of all request times)
    # user = await get_user(user_id)
    # orders = await get_recent_orders(user_id)
    # notifications = await get_notifications(user_id)
    # analytics = await get_analytics(user_id)

    # CORRECT: Parallel (total time = max single request time)
    user, orders, notifications, analytics = await asyncio.gather(
        get_user(user_id),
        get_recent_orders(user_id),
        get_notifications(user_id),
        get_analytics(user_id),
        return_exceptions=True,  # Don't cancel all if one fails
    )

    return {
        "user": user if not isinstance(user, Exception) else None,
        "orders": orders if not isinstance(orders, Exception) else [],
        "notifications": notifications if not isinstance(notifications, Exception) else [],
        "analytics": analytics if not isinstance(analytics, Exception) else {},
    }
```

### 5.5 Timeouts on External Calls
- Set timeouts on ALL external service calls
- Use `asyncio.wait_for()` for custom timeout wrapping
- Have fallback behavior when external services are slow or down
```python
# REQUIRED: Timeout pattern
import asyncio

async def call_external_service(data: dict) -> dict:
    try:
        result = await asyncio.wait_for(
            http_client.post("https://api.external.com/process", json=data),
            timeout=10.0,  # 10 second timeout
        )
        return result.json()
    except asyncio.TimeoutError:
        logger.warning("External service timed out", service="external-api")
        return {"error": "Service temporarily unavailable", "fallback": True}
    except httpx.HTTPError as e:
        logger.error("External service error", error=str(e))
        return {"error": "Service error", "fallback": True}
```

---

## 6. Performance Monitoring

### 6.1 Application Performance Metrics
- Track request latency per endpoint (histogram)
- Track database query latency (histogram)
- Track cache hit/miss ratio (counter)
- Track external API call latency (histogram)
- Track active connections (gauge)
```python
# REQUIRED: Performance metrics
from prometheus_client import Histogram, Gauge, Counter

request_latency = Histogram(
    "http_request_duration_seconds",
    "HTTP request latency",
    ["method", "endpoint", "status"],
    buckets=[0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0, 10.0],
)

db_query_latency = Histogram(
    "db_query_duration_seconds",
    "Database query latency",
    ["operation", "table"],
    buckets=[0.001, 0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0],
)

active_db_connections = Gauge(
    "db_connections_active",
    "Active database connections",
)

external_api_latency = Histogram(
    "external_api_duration_seconds",
    "External API call latency",
    ["service", "endpoint"],
)
```

### 6.2 Slow Query Logging
- Log all queries taking longer than 100ms
- Include the query text, parameters, and execution time
- Alert on queries taking longer than 1 second
```python
# REQUIRED: Slow query detection
import time
from sqlalchemy import event

@event.listens_for(engine.sync_engine, "before_cursor_execute")
def before_cursor_execute(conn, cursor, statement, parameters, context, executemany):
    conn.info.setdefault("query_start_time", []).append(time.time())

@event.listens_for(engine.sync_engine, "after_cursor_execute")
def after_cursor_execute(conn, cursor, statement, parameters, context, executemany):
    total = time.time() - conn.info["query_start_time"].pop()
    if total > 0.1:  # 100ms threshold
        logger.warning(
            "slow_query",
            duration_ms=round(total * 1000, 2),
            query=statement[:500],
        )
    db_query_latency.labels(operation="query", table="unknown").observe(total)
```

---

## 7. Performance Checklist for Code Reviews

Every PR touching performance-sensitive code MUST verify:

- [ ] No `SELECT *` queries (explicit column selection)
- [ ] Pagination on all list endpoints (cursor-based preferred)
- [ ] Eager loading for accessed relationships (no N+1)
- [ ] Indexes on filtered/sorted/joined columns
- [ ] Async endpoints for all I/O operations
- [ ] Connection pooling configured for DB and Redis
- [ ] Cache-aside pattern for frequently read data
- [ ] Cache invalidation on data mutation
- [ ] Appropriate TTLs on all cached data
- [ ] No synchronous I/O in async code (no `requests`, no `time.sleep`)
- [ ] Timeouts on all external service calls
- [ ] `asyncio.gather()` for parallel independent I/O
- [ ] Response compression enabled
- [ ] Lazy loading for below-fold frontend components
- [ ] Debouncing on search/filter inputs
- [ ] Virtual scrolling for long lists (>100 items)
- [ ] Bundle size within limits
- [ ] Core Web Vitals targets met
- [ ] Performance metrics instrumented
- [ ] Slow query logging configured

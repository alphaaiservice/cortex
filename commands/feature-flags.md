---
description: "Generate feature flag system with MySQL + Redis cache, per-user/percentage rollout, kill switch, and admin UI. Usage: /feature-flags [init | create | list | toggle | cleanup]"
---

# Feature Flag System

Action: **$ARGUMENTS** (default: `init`)

Parse $ARGUMENTS:
- `init` — Generate the complete feature flag system (DB schema, service, API, admin UI)
- `create <flag-name> [--description "..."] [--rollout 0-100]` — Create a new feature flag
- `list` — Show all flags with status, rollout %, and usage stats
- `toggle <flag-name> [--env staging|production] [--on|--off]` — Toggle a flag
- `cleanup` — Find and remove stale/fully-rolled-out flags from code
- No argument = `init`

---

## Step 0: Detect Project Context

```bash
echo "=== Project Type ==="
ls package.json pyproject.toml build.gradle.kts pom.xml 2>/dev/null

echo "=== Backend Language ==="
if [ -f "pyproject.toml" ] || [ -f "requirements.txt" ]; then
  echo "Python/FastAPI detected"
elif [ -f "package.json" ] && grep -q "nestjs" package.json 2>/dev/null; then
  echo "NestJS detected"
elif [ -f "build.gradle.kts" ] || [ -f "pom.xml" ]; then
  echo "Spring Boot detected"
fi

echo "=== Existing Feature Flags ==="
grep -rn "feature.flag\|feature_flag\|FeatureFlag\|FEATURE_" --include="*.py" --include="*.ts" --include="*.java" . 2>/dev/null | grep -v node_modules | head -20

echo "=== Database ==="
grep -rn "mysql\|DATABASE_URL" .env* 2>/dev/null | head -5
grep -rn "redis\|REDIS" .env* 2>/dev/null | head -5
```

---

## Step 1: Database Schema (Action: `init`)

### MySQL Migration

Generate the feature flags table migration.

**Python (Alembic):**
```python
"""create feature flags tables

Revision ID: xxxx
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.mysql import JSON

def upgrade() -> None:
    op.create_table(
        'feature_flags',
        sa.Column('id', sa.Integer(), autoincrement=True, nullable=False),
        sa.Column('name', sa.String(100), nullable=False, unique=True, index=True),
        sa.Column('description', sa.Text(), nullable=True),
        sa.Column('enabled', sa.Boolean(), default=False, nullable=False),
        sa.Column('rollout_percentage', sa.Integer(), default=0, nullable=False),
        sa.Column('conditions', JSON, nullable=True),  # {"roles": ["admin"], "user_ids": [1,2,3], "regions": ["IN"]}
        sa.Column('kill_switch', sa.Boolean(), default=False, nullable=False),  # True = force OFF regardless
        sa.Column('stale_after', sa.DateTime(), nullable=True),  # When this flag should be reviewed
        sa.Column('created_by', sa.String(100), nullable=True),
        sa.Column('created_at', sa.DateTime(), server_default=sa.func.now(), nullable=False),
        sa.Column('updated_at', sa.DateTime(), server_default=sa.func.now(), onupdate=sa.func.now(), nullable=False),
        sa.PrimaryKeyConstraint('id'),
    )

    op.create_table(
        'feature_flag_overrides',
        sa.Column('id', sa.Integer(), autoincrement=True, nullable=False),
        sa.Column('flag_id', sa.Integer(), sa.ForeignKey('feature_flags.id', ondelete='CASCADE'), nullable=False),
        sa.Column('user_id', sa.Integer(), nullable=True),
        sa.Column('role', sa.String(50), nullable=True),
        sa.Column('enabled', sa.Boolean(), nullable=False),
        sa.Column('created_at', sa.DateTime(), server_default=sa.func.now(), nullable=False),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('flag_id', 'user_id', name='uq_flag_user'),
    )

    op.create_table(
        'feature_flag_audit_log',
        sa.Column('id', sa.Integer(), autoincrement=True, nullable=False),
        sa.Column('flag_id', sa.Integer(), sa.ForeignKey('feature_flags.id', ondelete='CASCADE'), nullable=False),
        sa.Column('action', sa.String(50), nullable=False),  # created, enabled, disabled, rollout_changed, deleted
        sa.Column('old_value', sa.Text(), nullable=True),
        sa.Column('new_value', sa.Text(), nullable=True),
        sa.Column('changed_by', sa.String(100), nullable=True),
        sa.Column('changed_at', sa.DateTime(), server_default=sa.func.now(), nullable=False),
        sa.PrimaryKeyConstraint('id'),
    )

def downgrade() -> None:
    op.drop_table('feature_flag_audit_log')
    op.drop_table('feature_flag_overrides')
    op.drop_table('feature_flags')
```

**NestJS (Prisma):**
```prisma
model FeatureFlag {
  id                Int       @id @default(autoincrement())
  name              String    @unique @db.VarChar(100)
  description       String?   @db.Text
  enabled           Boolean   @default(false)
  rolloutPercentage Int       @default(0) @map("rollout_percentage")
  conditions        Json?
  killSwitch        Boolean   @default(false) @map("kill_switch")
  staleAfter        DateTime? @map("stale_after")
  createdBy         String?   @map("created_by") @db.VarChar(100)
  createdAt         DateTime  @default(now()) @map("created_at")
  updatedAt         DateTime  @updatedAt @map("updated_at")

  overrides FeatureFlagOverride[]
  auditLogs FeatureFlagAuditLog[]

  @@map("feature_flags")
}

model FeatureFlagOverride {
  id        Int      @id @default(autoincrement())
  flagId    Int      @map("flag_id")
  userId    Int?     @map("user_id")
  role      String?  @db.VarChar(50)
  enabled   Boolean
  createdAt DateTime @default(now()) @map("created_at")

  flag FeatureFlag @relation(fields: [flagId], references: [id], onDelete: Cascade)

  @@unique([flagId, userId])
  @@map("feature_flag_overrides")
}

model FeatureFlagAuditLog {
  id        Int      @id @default(autoincrement())
  flagId    Int      @map("flag_id")
  action    String   @db.VarChar(50)
  oldValue  String?  @map("old_value") @db.Text
  newValue  String?  @map("new_value") @db.Text
  changedBy String?  @map("changed_by") @db.VarChar(100)
  changedAt DateTime @default(now()) @map("changed_at")

  flag FeatureFlag @relation(fields: [flagId], references: [id], onDelete: Cascade)

  @@map("feature_flag_audit_log")
}
```

**Spring Boot (JPA Entity):**
```java
@Entity
@Table(name = "feature_flags")
public class FeatureFlag {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(unique = true, nullable = false, length = 100)
    private String name;

    @Column(columnDefinition = "TEXT")
    private String description;

    @Column(nullable = false)
    private Boolean enabled = false;

    @Column(name = "rollout_percentage", nullable = false)
    private Integer rolloutPercentage = 0;

    @Column(columnDefinition = "JSON")
    private String conditions;

    @Column(name = "kill_switch", nullable = false)
    private Boolean killSwitch = false;

    @Column(name = "stale_after")
    private LocalDateTime staleAfter;

    @Column(name = "created_by", length = 100)
    private String createdBy;

    @Column(name = "created_at", updatable = false)
    private LocalDateTime createdAt = LocalDateTime.now();

    @Column(name = "updated_at")
    private LocalDateTime updatedAt = LocalDateTime.now();
}
```

---

## Step 2: Feature Flag Service

Generate the core service with Redis caching.

### Python (FastAPI):

```python
# app/services/feature_flag_service.py
import hashlib
import json
from typing import Optional
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from redis.asyncio import Redis

from app.models.feature_flag import FeatureFlag, FeatureFlagOverride
from app.repositories.feature_flag_repository import FeatureFlagRepository

CACHE_PREFIX = "ff:"
CACHE_TTL = 300  # 5 minutes


class FeatureFlagService:
    def __init__(self, db: AsyncSession, redis: Redis):
        self.repo = FeatureFlagRepository(db)
        self.redis = redis
        self.db = db

    async def is_enabled(
        self,
        flag_name: str,
        user_id: Optional[int] = None,
        user_role: Optional[str] = None,
    ) -> bool:
        """Check if a feature flag is enabled for a given user context."""

        # 1. Check Redis cache first
        cache_key = f"{CACHE_PREFIX}{flag_name}"
        cached = await self.redis.get(cache_key)

        if cached:
            flag_data = json.loads(cached)
        else:
            flag = await self.repo.get_by_name(flag_name)
            if not flag:
                return False
            flag_data = {
                "enabled": flag.enabled,
                "kill_switch": flag.kill_switch,
                "rollout_percentage": flag.rollout_percentage,
                "conditions": flag.conditions,
            }
            await self.redis.setex(cache_key, CACHE_TTL, json.dumps(flag_data))

        # 2. Kill switch overrides everything
        if flag_data["kill_switch"]:
            return False

        # 3. Check if globally disabled
        if not flag_data["enabled"]:
            return False

        # 4. Check user-specific override
        if user_id:
            override = await self._get_user_override(flag_name, user_id)
            if override is not None:
                return override

        # 5. Check role-based conditions
        conditions = flag_data.get("conditions") or {}
        if user_role and "roles" in conditions:
            if user_role in conditions["roles"]:
                return True

        # 6. Check user ID allowlist
        if user_id and "user_ids" in conditions:
            if user_id in conditions["user_ids"]:
                return True

        # 7. Percentage rollout (deterministic based on user_id + flag_name)
        rollout = flag_data["rollout_percentage"]
        if rollout >= 100:
            return True
        if rollout <= 0:
            return False
        if user_id:
            hash_input = f"{flag_name}:{user_id}"
            hash_value = int(hashlib.md5(hash_input.encode()).hexdigest(), 16) % 100
            return hash_value < rollout

        return flag_data["enabled"]

    async def _get_user_override(self, flag_name: str, user_id: int) -> Optional[bool]:
        cache_key = f"{CACHE_PREFIX}{flag_name}:user:{user_id}"
        cached = await self.redis.get(cache_key)
        if cached is not None:
            return json.loads(cached)

        override = await self.repo.get_override(flag_name, user_id)
        if override is not None:
            await self.redis.setex(cache_key, CACHE_TTL, json.dumps(override.enabled))
            return override.enabled
        return None

    async def create_flag(self, name: str, description: str = "", rollout: int = 0, created_by: str = None) -> FeatureFlag:
        flag = await self.repo.create(
            name=name,
            description=description,
            rollout_percentage=rollout,
            created_by=created_by,
        )
        await self._invalidate_cache(name)
        await self._audit_log(flag.id, "created", None, f"rollout={rollout}", created_by)
        return flag

    async def toggle_flag(self, name: str, enabled: bool, changed_by: str = None) -> FeatureFlag:
        flag = await self.repo.get_by_name(name)
        if not flag:
            raise ValueError(f"Flag '{name}' not found")
        old_value = str(flag.enabled)
        flag = await self.repo.update(flag.id, enabled=enabled)
        await self._invalidate_cache(name)
        await self._audit_log(flag.id, "enabled" if enabled else "disabled", old_value, str(enabled), changed_by)
        return flag

    async def set_rollout(self, name: str, percentage: int, changed_by: str = None) -> FeatureFlag:
        if not 0 <= percentage <= 100:
            raise ValueError("Rollout percentage must be 0-100")
        flag = await self.repo.get_by_name(name)
        if not flag:
            raise ValueError(f"Flag '{name}' not found")
        old_value = str(flag.rollout_percentage)
        flag = await self.repo.update(flag.id, rollout_percentage=percentage)
        await self._invalidate_cache(name)
        await self._audit_log(flag.id, "rollout_changed", old_value, str(percentage), changed_by)
        return flag

    async def kill(self, name: str, changed_by: str = None) -> FeatureFlag:
        """Emergency kill switch — force disable regardless of other settings."""
        flag = await self.repo.get_by_name(name)
        if not flag:
            raise ValueError(f"Flag '{name}' not found")
        flag = await self.repo.update(flag.id, kill_switch=True)
        await self._invalidate_cache(name)
        await self._audit_log(flag.id, "kill_switch_activated", "false", "true", changed_by)
        return flag

    async def _invalidate_cache(self, flag_name: str):
        pattern = f"{CACHE_PREFIX}{flag_name}*"
        keys = []
        async for key in self.redis.scan_iter(pattern):
            keys.append(key)
        if keys:
            await self.redis.delete(*keys)

    async def _audit_log(self, flag_id: int, action: str, old_value: str, new_value: str, changed_by: str):
        await self.repo.create_audit_log(
            flag_id=flag_id,
            action=action,
            old_value=old_value,
            new_value=new_value,
            changed_by=changed_by,
        )
```

---

## Step 3: API Endpoints

Generate REST API for feature flag management (admin-only).

### Python (FastAPI):

```python
# app/api/admin/feature_flags.py
from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, Field
from typing import Optional, List
from app.services.feature_flag_service import FeatureFlagService
from app.api.deps import get_current_admin_user, get_feature_flag_service

router = APIRouter(prefix="/admin/feature-flags", tags=["Feature Flags"])


class CreateFlagRequest(BaseModel):
    name: str = Field(..., regex=r"^[a-z][a-z0-9_]*$", max_length=100)
    description: str = ""
    rollout_percentage: int = Field(0, ge=0, le=100)
    conditions: Optional[dict] = None


class UpdateFlagRequest(BaseModel):
    enabled: Optional[bool] = None
    rollout_percentage: Optional[int] = Field(None, ge=0, le=100)
    description: Optional[str] = None
    conditions: Optional[dict] = None
    kill_switch: Optional[bool] = None


class FlagResponse(BaseModel):
    id: int
    name: str
    description: Optional[str]
    enabled: bool
    rollout_percentage: int
    conditions: Optional[dict]
    kill_switch: bool
    stale_after: Optional[str]
    created_by: Optional[str]
    created_at: str
    updated_at: str


@router.get("/", response_model=List[FlagResponse])
async def list_flags(
    service: FeatureFlagService = Depends(get_feature_flag_service),
    admin=Depends(get_current_admin_user),
):
    """List all feature flags with current status."""
    return await service.list_all()


@router.post("/", response_model=FlagResponse, status_code=201)
async def create_flag(
    body: CreateFlagRequest,
    service: FeatureFlagService = Depends(get_feature_flag_service),
    admin=Depends(get_current_admin_user),
):
    """Create a new feature flag."""
    return await service.create_flag(
        name=body.name,
        description=body.description,
        rollout=body.rollout_percentage,
        created_by=admin.email,
    )


@router.patch("/{flag_name}", response_model=FlagResponse)
async def update_flag(
    flag_name: str,
    body: UpdateFlagRequest,
    service: FeatureFlagService = Depends(get_feature_flag_service),
    admin=Depends(get_current_admin_user),
):
    """Update a feature flag (toggle, rollout, kill switch)."""
    return await service.update_flag(flag_name, body, changed_by=admin.email)


@router.post("/{flag_name}/kill", response_model=FlagResponse)
async def kill_flag(
    flag_name: str,
    service: FeatureFlagService = Depends(get_feature_flag_service),
    admin=Depends(get_current_admin_user),
):
    """Emergency kill switch — immediately disable a flag."""
    return await service.kill(flag_name, changed_by=admin.email)


@router.delete("/{flag_name}", status_code=204)
async def delete_flag(
    flag_name: str,
    service: FeatureFlagService = Depends(get_feature_flag_service),
    admin=Depends(get_current_admin_user),
):
    """Delete a feature flag (ensure it's removed from code first)."""
    await service.delete_flag(flag_name, changed_by=admin.email)


@router.get("/{flag_name}/audit", response_model=list)
async def get_audit_log(
    flag_name: str,
    service: FeatureFlagService = Depends(get_feature_flag_service),
    admin=Depends(get_current_admin_user),
):
    """Get change history for a feature flag."""
    return await service.get_audit_log(flag_name)


# ─── Public endpoint for client-side evaluation ───

@router.get("/evaluate/{flag_name}")
async def evaluate_flag(
    flag_name: str,
    service: FeatureFlagService = Depends(get_feature_flag_service),
    user=Depends(get_current_user),  # Regular user, not admin
):
    """Check if a feature flag is enabled for the current user."""
    enabled = await service.is_enabled(
        flag_name,
        user_id=user.id,
        user_role=user.role,
    )
    return {"flag": flag_name, "enabled": enabled}
```

---

## Step 4: Client-Side SDK / Helper

Generate a helper for using feature flags in application code.

### Python Decorator:
```python
# app/core/feature_flags.py
from functools import wraps
from fastapi import HTTPException

def require_feature(flag_name: str):
    """Decorator to gate an endpoint behind a feature flag."""
    def decorator(func):
        @wraps(func)
        async def wrapper(*args, **kwargs):
            # Extract user from kwargs (injected by Depends)
            request = kwargs.get("request")
            user = kwargs.get("current_user")
            ff_service = kwargs.get("feature_flag_service")

            if ff_service:
                enabled = await ff_service.is_enabled(
                    flag_name,
                    user_id=user.id if user else None,
                    user_role=user.role if user else None,
                )
                if not enabled:
                    raise HTTPException(status_code=404, detail="Not found")

            return await func(*args, **kwargs)
        return wrapper
    return decorator
```

### Frontend (React/Next.js):
```typescript
// hooks/useFeatureFlag.ts
import { useEffect, useState } from 'react';

export function useFeatureFlag(flagName: string): boolean {
  const [enabled, setEnabled] = useState(false);

  useEffect(() => {
    fetch(`/api/v1/feature-flags/evaluate/${flagName}`, {
      credentials: 'include',
    })
      .then(res => res.json())
      .then(data => setEnabled(data.enabled))
      .catch(() => setEnabled(false));  // Fail closed
  }, [flagName]);

  return enabled;
}

// Usage in component:
// const showNewUI = useFeatureFlag('new_dashboard_ui');
// {showNewUI ? <NewDashboard /> : <OldDashboard />}
```

### React Native:
```typescript
// hooks/useFeatureFlag.ts
import { useQuery } from '@tanstack/react-query';
import { apiClient } from '@/lib/api';

export function useFeatureFlag(flagName: string): boolean {
  const { data } = useQuery({
    queryKey: ['feature-flag', flagName],
    queryFn: () => apiClient.get(`/feature-flags/evaluate/${flagName}`),
    staleTime: 5 * 60 * 1000, // Cache for 5 minutes
    placeholderData: { enabled: false },
  });
  return data?.enabled ?? false;
}
```

---

## Step 5: Stale Flag Cleanup (Action: `cleanup`)

Scan the codebase for feature flag references and identify stale flags.

1. **Find all flag references in code**:
```bash
grep -rn "is_enabled\|useFeatureFlag\|require_feature\|feature_flag\|FEATURE_" \
  --include="*.py" --include="*.ts" --include="*.tsx" --include="*.java" \
  --exclude-dir=node_modules --exclude-dir=.venv --exclude-dir=__pycache__ \
  . 2>/dev/null
```

2. **Compare with database flags** — query all flags and their status.

3. **Report stale flags**:
```
╔══════════════════════════════════════════════════════════════╗
║     FEATURE FLAG CLEANUP REPORT                              ║
╠══════════════════════════════════════════════════════════════╣
║                                                              ║
║  Flag Name              │ Status  │ Rollout │ Code Refs │ Age║
║  ───────────────────────┼─────────┼─────────┼──────────┼────║
║  new_dashboard_ui       │ ON 100% │ 100%    │ 4 files  │ 90d║  ← STALE: fully rolled out
║  beta_search            │ ON 100% │ 100%    │ 2 files  │ 60d║  ← STALE: fully rolled out
║  experimental_ai_chat   │ ON 25%  │ 25%     │ 3 files  │ 30d║
║  holiday_promo          │ OFF     │ 0%      │ 1 file   │120d║  ← STALE: disabled > 90 days
║  legacy_payment_flow    │ OFF     │ 0%      │ 0 files  │180d║  ← DEAD: no code references
║                                                              ║
║  Recommendations:                                            ║
║    🧹 Remove 'new_dashboard_ui': 100% for 90d, safe to clean║
║    🧹 Remove 'beta_search': 100% for 60d, safe to clean     ║
║    🗑️ Delete 'holiday_promo': disabled 120d, likely dead     ║
║    🗑️ Delete 'legacy_payment_flow': no code refs, orphaned  ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
```

4. For each stale flag, offer to:
   - Remove the flag check from code (replace with `true` or `false`)
   - Remove the conditional branches
   - Delete the flag from the database
   - Log the cleanup in the audit table

---

## Step 6: Output Summary

```
╔══════════════════════════════════════════════════════════════╗
║     FEATURE FLAGS SYSTEM GENERATED                           ║
╠══════════════════════════════════════════════════════════════╣
║                                                              ║
║  Architecture: MySQL (source of truth) + Redis (5min cache)  ║
║  Evaluation:   Deterministic (user_id + flag_name hash)      ║
║  Kill Switch:  Per-flag emergency disable                    ║
║  Audit:        Full change history with who/what/when        ║
║                                                              ║
║  Generated Files:                                            ║
║    Migration:     feature_flags + overrides + audit tables    ║
║    Service:       FeatureFlagService with Redis caching       ║
║    API:           /admin/feature-flags (CRUD + kill + audit)  ║
║    Evaluate API:  /feature-flags/evaluate/{name}              ║
║    Decorator:     @require_feature("flag_name")               ║
║    React Hook:    useFeatureFlag("flag_name")                 ║
║                                                              ║
║  Rollout Strategies:                                         ║
║    Boolean:     ON/OFF for all users                         ║
║    Percentage:  Gradual rollout (0-100%)                     ║
║    User list:   Specific user IDs                            ║
║    Role-based:  By user role (admin, beta, etc.)             ║
║    Kill switch: Emergency disable override                    ║
║                                                              ║
║  Next Steps:                                                 ║
║    1. Run migration: alembic upgrade head                    ║
║    2. Register router in app/main.py                         ║
║    3. Create first flag: /feature-flags create my_feature    ║
║    4. Use in code: @require_feature("my_feature")            ║
╚══════════════════════════════════════════════════════════════╝
```

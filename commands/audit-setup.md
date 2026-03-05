---
description: "Generate security audit logging system with immutable event trail, compliance reporting (GDPR/SOC2), and suspicious activity alerting. Usage: /audit-setup [init | report | alerts | compliance]"
---

# Security Audit Logging System

Action: **$ARGUMENTS** (default: `init`)

Parse $ARGUMENTS:
- `init` — Generate the complete audit logging system (schema, middleware, service, dashboard)
- `report` — Generate an audit report for a specified time period
- `alerts` — Configure alerting rules for suspicious activity patterns
- `compliance` — Generate compliance checklist and evidence for GDPR/SOC 2/HIPAA
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

echo "=== Existing Audit/Logging ==="
grep -rn "audit\|AuditLog\|audit_log" --include="*.py" --include="*.ts" --include="*.java" . 2>/dev/null | grep -v node_modules | head -20

echo "=== Auth System ==="
find . -maxdepth 5 -path "*/auth*" -name "*.py" -o -path "*/auth*" -name "*.ts" -o -path "*/auth*" -name "*.java" 2>/dev/null | grep -v node_modules | head -10

echo "=== Database ==="
grep -rn "mysql\|mongodb\|DATABASE_URL\|MONGO" .env* 2>/dev/null | head -5
```

Determine:
- Backend language (Python/NestJS/Spring Boot)
- Which database to use for audit logs (MySQL for structured, MongoDB for high-volume)
- Whether auth system exists (to instrument login/logout events)

---

## Step 1: Audit Event Categories

Define the complete list of auditable events:

### Authentication Events (MUST audit)
| Event | Severity | Data Captured |
|-------|----------|---------------|
| `auth.login.success` | INFO | user_id, IP, user_agent, method (password/oauth) |
| `auth.login.failure` | WARNING | email_attempted, IP, user_agent, failure_reason |
| `auth.logout` | INFO | user_id, IP |
| `auth.token.refresh` | INFO | user_id, IP |
| `auth.password.change` | WARNING | user_id, IP |
| `auth.password.reset.request` | WARNING | email, IP |
| `auth.password.reset.complete` | WARNING | user_id, IP |
| `auth.2fa.enable` | WARNING | user_id, IP |
| `auth.2fa.disable` | CRITICAL | user_id, IP |
| `auth.account.lockout` | CRITICAL | user_id, IP, failed_attempts |

### Authorization Events (MUST audit)
| Event | Severity | Data Captured |
|-------|----------|---------------|
| `authz.access.denied` | WARNING | user_id, resource, action, IP |
| `authz.role.change` | CRITICAL | target_user_id, old_role, new_role, changed_by |
| `authz.permission.grant` | CRITICAL | target_user_id, permission, granted_by |
| `authz.permission.revoke` | CRITICAL | target_user_id, permission, revoked_by |

### Data Events (SHOULD audit)
| Event | Severity | Data Captured |
|-------|----------|---------------|
| `data.export` | WARNING | user_id, export_type, record_count, IP |
| `data.bulk_delete` | CRITICAL | user_id, table, record_count, IP |
| `data.sensitive.access` | INFO | user_id, resource_type, resource_id |
| `data.pii.access` | WARNING | user_id, data_type (email/phone/address), resource_id |
| `data.gdpr.deletion.request` | CRITICAL | user_id, requester_id |
| `data.gdpr.deletion.complete` | CRITICAL | user_id, tables_affected, records_deleted |

### Admin Events (MUST audit)
| Event | Severity | Data Captured |
|-------|----------|---------------|
| `admin.user.create` | INFO | target_user_id, created_by, role |
| `admin.user.disable` | WARNING | target_user_id, disabled_by, reason |
| `admin.user.delete` | CRITICAL | target_user_id, deleted_by |
| `admin.config.change` | WARNING | config_key, old_value (redacted), new_value (redacted), changed_by |
| `admin.feature_flag.change` | INFO | flag_name, action, changed_by |
| `admin.backup.trigger` | INFO | backup_type, triggered_by |
| `admin.deploy` | WARNING | version, environment, deployed_by |

### Payment Events (MUST audit for financial compliance)
| Event | Severity | Data Captured |
|-------|----------|---------------|
| `payment.charge.success` | INFO | user_id, amount, currency, provider_ref |
| `payment.charge.failure` | WARNING | user_id, amount, failure_reason |
| `payment.refund` | WARNING | user_id, amount, refund_reason, approved_by |
| `payment.subscription.change` | INFO | user_id, old_plan, new_plan |

---

## Step 2: Database Schema

### MySQL Audit Table

**Python (Alembic migration):**
```python
"""create audit log tables

Revision ID: xxxx
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.mysql import JSON, BIGINT

def upgrade() -> None:
    op.create_table(
        'audit_logs',
        sa.Column('id', BIGINT(unsigned=True), autoincrement=True, nullable=False),
        sa.Column('event_type', sa.String(100), nullable=False, index=True),
        sa.Column('severity', sa.Enum('INFO', 'WARNING', 'CRITICAL', name='audit_severity'), nullable=False, index=True),
        sa.Column('actor_id', sa.Integer(), nullable=True, index=True),  # User who performed the action
        sa.Column('actor_email', sa.String(255), nullable=True),
        sa.Column('actor_role', sa.String(50), nullable=True),
        sa.Column('target_type', sa.String(100), nullable=True),  # e.g., "user", "order", "config"
        sa.Column('target_id', sa.String(100), nullable=True),
        sa.Column('action', sa.String(50), nullable=False),  # e.g., "create", "update", "delete", "access"
        sa.Column('description', sa.Text(), nullable=True),
        sa.Column('metadata', JSON, nullable=True),  # Additional structured data
        sa.Column('ip_address', sa.String(45), nullable=True),
        sa.Column('user_agent', sa.String(500), nullable=True),
        sa.Column('request_id', sa.String(36), nullable=True, index=True),  # Correlation ID
        sa.Column('session_id', sa.String(100), nullable=True),
        sa.Column('created_at', sa.DateTime(), server_default=sa.func.now(), nullable=False, index=True),
        sa.PrimaryKeyConstraint('id'),
    )

    # Composite indexes for common queries
    op.create_index('ix_audit_actor_time', 'audit_logs', ['actor_id', 'created_at'])
    op.create_index('ix_audit_event_time', 'audit_logs', ['event_type', 'created_at'])
    op.create_index('ix_audit_target', 'audit_logs', ['target_type', 'target_id'])
    op.create_index('ix_audit_severity_time', 'audit_logs', ['severity', 'created_at'])


def downgrade() -> None:
    op.drop_table('audit_logs')
```

### MongoDB Audit Collection (for high-volume)

```python
# If using MongoDB for audit logs (recommended for high-volume applications)
# Collection: audit_logs
# Schema:
{
    "event_type": "auth.login.success",
    "severity": "INFO",
    "actor": {
        "id": 123,
        "email": "user@example.com",
        "role": "admin"
    },
    "target": {
        "type": "user",
        "id": "456"
    },
    "action": "login",
    "description": "Successful login via password",
    "metadata": {
        "method": "password",
        "mfa_used": True
    },
    "context": {
        "ip_address": "192.168.1.1",
        "user_agent": "Mozilla/5.0...",
        "request_id": "req_abc123",
        "session_id": "sess_xyz789"
    },
    "created_at": "2025-01-15T10:30:00Z"
}

# Indexes:
# { "event_type": 1, "created_at": -1 }
# { "actor.id": 1, "created_at": -1 }
# { "target.type": 1, "target.id": 1 }
# { "severity": 1, "created_at": -1 }
# { "created_at": 1 }, expireAfterSeconds: 31536000  # TTL: 1 year auto-delete
```

---

## Step 3: Audit Service

### Python (FastAPI):

```python
# app/services/audit_service.py
import json
from datetime import datetime, timedelta
from typing import Optional
from sqlalchemy.ext.asyncio import AsyncSession
from fastapi import Request

from app.models.audit_log import AuditLog
from app.repositories.audit_repository import AuditRepository


class AuditService:
    """Immutable audit logging service.

    All audit logs are append-only. There is intentionally NO update or delete method.
    Logs can only be queried and exported.
    """

    def __init__(self, db: AsyncSession):
        self.repo = AuditRepository(db)

    async def log(
        self,
        event_type: str,
        severity: str,
        action: str,
        request: Optional[Request] = None,
        actor_id: Optional[int] = None,
        actor_email: Optional[str] = None,
        actor_role: Optional[str] = None,
        target_type: Optional[str] = None,
        target_id: Optional[str] = None,
        description: Optional[str] = None,
        metadata: Optional[dict] = None,
    ) -> AuditLog:
        """Create an immutable audit log entry."""

        ip_address = None
        user_agent = None
        request_id = None

        if request:
            ip_address = request.client.host if request.client else None
            user_agent = request.headers.get("user-agent", "")[:500]
            request_id = request.headers.get("x-request-id")

        return await self.repo.create(
            event_type=event_type,
            severity=severity,
            actor_id=actor_id,
            actor_email=actor_email,
            actor_role=actor_role,
            target_type=target_type,
            target_id=str(target_id) if target_id else None,
            action=action,
            description=description,
            metadata=metadata,
            ip_address=ip_address,
            user_agent=user_agent,
            request_id=request_id,
        )

    # ─── Convenience Methods ───

    async def log_auth_success(self, request: Request, user_id: int, email: str, method: str = "password"):
        await self.log(
            event_type="auth.login.success",
            severity="INFO",
            action="login",
            request=request,
            actor_id=user_id,
            actor_email=email,
            description=f"Successful login via {method}",
            metadata={"method": method},
        )

    async def log_auth_failure(self, request: Request, email: str, reason: str):
        await self.log(
            event_type="auth.login.failure",
            severity="WARNING",
            action="login_attempt",
            request=request,
            actor_email=email,
            description=f"Failed login: {reason}",
            metadata={"reason": reason},
        )

    async def log_access_denied(self, request: Request, user_id: int, resource: str, action: str):
        await self.log(
            event_type="authz.access.denied",
            severity="WARNING",
            action="access_denied",
            request=request,
            actor_id=user_id,
            target_type="resource",
            target_id=resource,
            description=f"Access denied: {action} on {resource}",
        )

    async def log_role_change(self, request: Request, changed_by: int, target_user_id: int, old_role: str, new_role: str):
        await self.log(
            event_type="authz.role.change",
            severity="CRITICAL",
            action="role_change",
            request=request,
            actor_id=changed_by,
            target_type="user",
            target_id=str(target_user_id),
            description=f"Role changed from {old_role} to {new_role}",
            metadata={"old_role": old_role, "new_role": new_role},
        )

    async def log_data_export(self, request: Request, user_id: int, export_type: str, record_count: int):
        await self.log(
            event_type="data.export",
            severity="WARNING",
            action="export",
            request=request,
            actor_id=user_id,
            description=f"Exported {record_count} {export_type} records",
            metadata={"export_type": export_type, "record_count": record_count},
        )

    async def log_data_deletion(self, request: Request, user_id: int, table: str, count: int):
        await self.log(
            event_type="data.bulk_delete",
            severity="CRITICAL",
            action="bulk_delete",
            request=request,
            actor_id=user_id,
            target_type=table,
            description=f"Bulk deleted {count} records from {table}",
            metadata={"table": table, "record_count": count},
        )

    async def log_gdpr_deletion(self, request: Request, requester_id: int, target_user_id: int, tables: list, records: int):
        await self.log(
            event_type="data.gdpr.deletion.complete",
            severity="CRITICAL",
            action="gdpr_deletion",
            request=request,
            actor_id=requester_id,
            target_type="user",
            target_id=str(target_user_id),
            description=f"GDPR deletion: {records} records across {len(tables)} tables",
            metadata={"tables_affected": tables, "records_deleted": records},
        )

    # ─── Query Methods ───

    async def query(
        self,
        event_type: Optional[str] = None,
        severity: Optional[str] = None,
        actor_id: Optional[int] = None,
        target_type: Optional[str] = None,
        target_id: Optional[str] = None,
        start_date: Optional[datetime] = None,
        end_date: Optional[datetime] = None,
        limit: int = 100,
        offset: int = 0,
    ) -> list:
        return await self.repo.query(
            event_type=event_type,
            severity=severity,
            actor_id=actor_id,
            target_type=target_type,
            target_id=target_id,
            start_date=start_date,
            end_date=end_date,
            limit=limit,
            offset=offset,
        )

    async def get_user_activity(self, user_id: int, days: int = 30) -> list:
        start = datetime.utcnow() - timedelta(days=days)
        return await self.query(actor_id=user_id, start_date=start)

    async def get_critical_events(self, hours: int = 24) -> list:
        start = datetime.utcnow() - timedelta(hours=hours)
        return await self.query(severity="CRITICAL", start_date=start)
```

---

## Step 4: Audit Middleware

Generate middleware that automatically captures audit-worthy events.

### Python (FastAPI):

```python
# app/middleware/audit_middleware.py
import time
import uuid
from fastapi import Request, Response
from starlette.middleware.base import BaseHTTPMiddleware

from app.services.audit_service import AuditService

# Paths that should always be audited
AUDITED_PATHS = {
    "/api/v1/auth/login": "auth.login",
    "/api/v1/auth/logout": "auth.logout",
    "/api/v1/auth/register": "auth.register",
    "/api/v1/auth/refresh": "auth.token.refresh",
    "/api/v1/auth/forgot-password": "auth.password.reset.request",
    "/api/v1/auth/reset-password": "auth.password.reset.complete",
    "/api/v1/auth/change-password": "auth.password.change",
}

# Methods that modify data
WRITE_METHODS = {"POST", "PUT", "PATCH", "DELETE"}


class AuditMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        # Add request ID for correlation
        request_id = request.headers.get("x-request-id", str(uuid.uuid4()))
        request.state.request_id = request_id

        # Record start time
        start_time = time.time()

        # Process request
        response: Response = await call_next(request)

        # Calculate duration
        duration_ms = int((time.time() - start_time) * 1000)

        # Add request ID to response
        response.headers["X-Request-ID"] = request_id

        # Determine if this request should be audited
        path = request.url.path
        method = request.method

        # Always audit authentication endpoints
        if path in AUDITED_PATHS:
            await self._audit_auth_event(request, response, path, duration_ms)

        # Audit all admin API calls
        elif "/admin/" in path and method in WRITE_METHODS:
            await self._audit_admin_event(request, response, path, method, duration_ms)

        # Audit failed authorization (403)
        elif response.status_code == 403:
            await self._audit_access_denied(request, path)

        # Audit server errors (500) on write operations
        elif response.status_code >= 500 and method in WRITE_METHODS:
            await self._audit_server_error(request, path, method, response.status_code)

        return response

    async def _audit_auth_event(self, request, response, path, duration_ms):
        # Implementation: log auth events based on path and response status
        pass  # Filled in by the generated code based on project structure

    async def _audit_admin_event(self, request, response, path, method, duration_ms):
        # Implementation: log all admin panel actions
        pass

    async def _audit_access_denied(self, request, path):
        # Implementation: log 403 responses
        pass

    async def _audit_server_error(self, request, path, method, status_code):
        # Implementation: log 500 errors on write operations
        pass
```

---

## Step 5: Suspicious Activity Detection (Action: `alerts`)

Generate alerting rules that detect suspicious patterns.

### Alert Rules:

```python
# app/services/audit_alert_service.py
from datetime import datetime, timedelta
from app.services.audit_service import AuditService

ALERT_RULES = [
    {
        "name": "brute_force_login",
        "description": "Multiple failed logins from same IP",
        "query": {"event_type": "auth.login.failure"},
        "threshold": 10,
        "window_minutes": 15,
        "group_by": "ip_address",
        "severity": "CRITICAL",
        "action": "Block IP and notify security team",
    },
    {
        "name": "impossible_travel",
        "description": "Login from different countries within 1 hour",
        "query": {"event_type": "auth.login.success"},
        "check": "geo_distance",
        "window_minutes": 60,
        "group_by": "actor_id",
        "severity": "CRITICAL",
        "action": "Force re-authentication and notify user",
    },
    {
        "name": "privilege_escalation",
        "description": "User role changed to admin",
        "query": {"event_type": "authz.role.change"},
        "check": "metadata.new_role == 'admin'",
        "severity": "CRITICAL",
        "action": "Notify all admins immediately",
    },
    {
        "name": "mass_data_export",
        "description": "Large data export (> 10,000 records)",
        "query": {"event_type": "data.export"},
        "check": "metadata.record_count > 10000",
        "severity": "WARNING",
        "action": "Notify data protection officer",
    },
    {
        "name": "off_hours_admin_access",
        "description": "Admin actions outside business hours",
        "query": {"event_type__startswith": "admin."},
        "check": "hour < 6 or hour > 22",
        "severity": "WARNING",
        "action": "Log and review next business day",
    },
    {
        "name": "bulk_deletion",
        "description": "Bulk deletion of records",
        "query": {"event_type": "data.bulk_delete"},
        "check": "metadata.record_count > 100",
        "severity": "CRITICAL",
        "action": "Notify admin team and verify backup exists",
    },
    {
        "name": "2fa_disabled",
        "description": "Two-factor authentication disabled",
        "query": {"event_type": "auth.2fa.disable"},
        "severity": "CRITICAL",
        "action": "Notify user via email and flag account for review",
    },
    {
        "name": "concurrent_sessions",
        "description": "Login from 5+ different IPs in 1 hour",
        "query": {"event_type": "auth.login.success"},
        "threshold": 5,
        "window_minutes": 60,
        "group_by": "actor_id",
        "unique_field": "ip_address",
        "severity": "WARNING",
        "action": "Notify user of potential account sharing",
    },
]
```

### Alert Evaluation (Celery/BullMQ task):

```python
# app/tasks/audit_alerts.py
from celery import shared_task
from datetime import datetime, timedelta

@shared_task
def check_audit_alerts():
    """Run every 5 minutes via Celery beat."""
    from app.services.audit_service import AuditService
    from app.services.notification_service import NotificationService

    for rule in ALERT_RULES:
        window_start = datetime.utcnow() - timedelta(minutes=rule.get("window_minutes", 15))

        events = AuditService.query(
            event_type=rule["query"].get("event_type"),
            start_date=window_start,
        )

        # Group and check thresholds
        if "threshold" in rule:
            groups = {}
            for event in events:
                key = getattr(event, rule["group_by"])
                groups.setdefault(key, []).append(event)

            for key, group_events in groups.items():
                if len(group_events) >= rule["threshold"]:
                    trigger_alert(rule, key, group_events)

        # Check individual conditions
        if "check" in rule:
            for event in events:
                if evaluate_condition(rule["check"], event):
                    trigger_alert(rule, event.actor_id, [event])
```

### Cron/Celery Beat Schedule:

```python
# Check audit alerts every 5 minutes
CELERYBEAT_SCHEDULE = {
    "check-audit-alerts": {
        "task": "app.tasks.audit_alerts.check_audit_alerts",
        "schedule": 300.0,  # 5 minutes
    },
}
```

---

## Step 6: Admin API for Audit Logs

```python
# app/api/admin/audit.py
from fastapi import APIRouter, Depends, Query
from datetime import datetime, timedelta
from typing import Optional

from app.services.audit_service import AuditService
from app.api.deps import get_current_admin_user, get_audit_service

router = APIRouter(prefix="/admin/audit", tags=["Audit"])


@router.get("/logs")
async def query_audit_logs(
    event_type: Optional[str] = None,
    severity: Optional[str] = None,
    actor_id: Optional[int] = None,
    target_type: Optional[str] = None,
    target_id: Optional[str] = None,
    start_date: Optional[datetime] = None,
    end_date: Optional[datetime] = None,
    limit: int = Query(50, le=500),
    offset: int = 0,
    service: AuditService = Depends(get_audit_service),
    admin=Depends(get_current_admin_user),
):
    """Query audit logs with filters. Admin-only."""
    return await service.query(
        event_type=event_type,
        severity=severity,
        actor_id=actor_id,
        target_type=target_type,
        target_id=target_id,
        start_date=start_date,
        end_date=end_date,
        limit=limit,
        offset=offset,
    )


@router.get("/logs/user/{user_id}")
async def get_user_audit_trail(
    user_id: int,
    days: int = Query(30, le=365),
    service: AuditService = Depends(get_audit_service),
    admin=Depends(get_current_admin_user),
):
    """Get complete audit trail for a specific user."""
    return await service.get_user_activity(user_id, days)


@router.get("/alerts/critical")
async def get_critical_events(
    hours: int = Query(24, le=168),
    service: AuditService = Depends(get_audit_service),
    admin=Depends(get_current_admin_user),
):
    """Get all critical security events in the last N hours."""
    return await service.get_critical_events(hours)


@router.get("/summary")
async def get_audit_summary(
    days: int = Query(7, le=90),
    service: AuditService = Depends(get_audit_service),
    admin=Depends(get_current_admin_user),
):
    """Get audit activity summary (event counts by type and severity)."""
    start = datetime.utcnow() - timedelta(days=days)
    return await service.get_summary(start)


@router.get("/export")
async def export_audit_logs(
    start_date: datetime,
    end_date: datetime,
    format: str = Query("csv", regex="^(csv|json)$"),
    service: AuditService = Depends(get_audit_service),
    admin=Depends(get_current_admin_user),
):
    """Export audit logs for compliance review. Max 90-day range."""
    if (end_date - start_date).days > 90:
        raise HTTPException(400, "Export range cannot exceed 90 days")

    # Audit the export itself
    await service.log(
        event_type="data.export",
        severity="WARNING",
        action="audit_export",
        actor_id=admin.id,
        actor_email=admin.email,
        description=f"Audit log export: {start_date} to {end_date} ({format})",
        metadata={"format": format, "start": str(start_date), "end": str(end_date)},
    )

    return await service.export(start_date, end_date, format)
```

---

## Step 7: Compliance Reporting (Action: `compliance`)

Generate compliance evidence documents.

### GDPR Compliance Checklist:

```markdown
# GDPR Compliance Evidence — Audit System

## Article 5: Principles relating to processing of personal data
- [x] **Lawfulness**: All data access is logged with purpose
- [x] **Purpose limitation**: Audit logs capture why data was accessed
- [x] **Data minimization**: Only necessary fields are logged
- [x] **Accuracy**: Timestamps are server-generated (not user-supplied)
- [x] **Storage limitation**: TTL configured for auto-deletion after retention period
- [x] **Integrity**: Audit logs are append-only (no update/delete)

## Article 15: Right of Access
- [x] `/admin/audit/logs/user/{id}` — retrieve all activity for a data subject

## Article 17: Right to Erasure
- [x] `audit.log_gdpr_deletion()` — logs erasure requests and completion
- [x] Audit logs themselves are retained for compliance (lawful basis: legal obligation)

## Article 30: Records of Processing Activities
- [x] All data processing activities are logged with:
  - Who (actor_id, actor_email, actor_role)
  - What (event_type, action, target_type, target_id)
  - When (created_at — server timestamp)
  - Where (ip_address, user_agent)
  - Why (description, metadata)

## Article 33: Notification of Personal Data Breach
- [x] Suspicious activity alerts configured (brute force, impossible travel, etc.)
- [x] Critical events trigger immediate notification to security team
- [x] Audit trail enables incident timeline reconstruction
```

### SOC 2 Controls:

```markdown
# SOC 2 Type II — Audit Evidence

## CC6.1: Logical and Physical Access Controls
- Evidence: `auth.login.*` events with IP and user agent
- Evidence: `authz.access.denied` events
- Evidence: `authz.role.change` events with before/after

## CC6.2: Prior to Issuing System Credentials
- Evidence: `admin.user.create` events
- Evidence: `authz.role.change` events

## CC6.3: Registration and Authorization of New Internal and External Users
- Evidence: `auth.register` events
- Evidence: `admin.user.create` events

## CC7.2: Monitoring of System Components
- Evidence: Audit middleware captures all admin operations
- Evidence: Alert rules detect anomalous patterns
- Evidence: Critical events trigger real-time notifications

## CC8.1: Authorization of Changes
- Evidence: `admin.config.change` events
- Evidence: `admin.deploy` events
- Evidence: `admin.feature_flag.change` events
```

---

## Step 8: Output Summary

```
╔══════════════════════════════════════════════════════════════╗
║     AUDIT LOGGING SYSTEM GENERATED                           ║
╠══════════════════════════════════════════════════════════════╣
║                                                              ║
║  Architecture:                                               ║
║    Storage:     MySQL (structured) / MongoDB (high-volume)   ║
║    Immutable:   Append-only (NO update/delete operations)    ║
║    Indexed:     event_type + actor_id + created_at           ║
║    Retention:   Configurable TTL (default: 1 year)           ║
║                                                              ║
║  Event Categories:                                           ║
║    Authentication:  10 event types                           ║
║    Authorization:   4 event types                            ║
║    Data Access:     6 event types                            ║
║    Admin Actions:   6 event types                            ║
║    Payments:        4 event types                            ║
║    TOTAL:           30 auditable event types                 ║
║                                                              ║
║  Alert Rules:       8 suspicious activity detectors          ║
║    Brute force login detection                               ║
║    Impossible travel detection                               ║
║    Privilege escalation alerts                               ║
║    Mass data export alerts                                   ║
║    Off-hours admin access                                    ║
║    Bulk deletion alerts                                      ║
║    2FA disable alerts                                        ║
║    Concurrent session alerts                                 ║
║                                                              ║
║  Compliance:                                                 ║
║    GDPR:  Articles 5, 15, 17, 30, 33 covered                ║
║    SOC 2: CC6.1, CC6.2, CC6.3, CC7.2, CC8.1 covered         ║
║                                                              ║
║  Generated Files:                                            ║
║    Migration:     audit_logs table with indexes               ║
║    Service:       AuditService (append-only, query, export)  ║
║    Middleware:     AuditMiddleware (auto-capture)             ║
║    Alerts:        8 suspicious activity rules + Celery task  ║
║    Admin API:     /admin/audit (query, export, summary)      ║
║    Compliance:    GDPR + SOC 2 evidence documents            ║
║                                                              ║
║  Next Steps:                                                 ║
║    1. Run migration: alembic upgrade head                    ║
║    2. Add AuditMiddleware to app/main.py                     ║
║    3. Register admin router in app/main.py                   ║
║    4. Add Celery beat schedule for alert checks              ║
║    5. Integrate audit.log_* calls into auth service          ║
║    6. Configure alert notifications (Slack/email)            ║
╚══════════════════════════════════════════════════════════════╝
```

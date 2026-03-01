---
name: security
description: "Auto-invoked when writing auth code, handling user input, configuring CORS/CSP, managing secrets, or implementing any security-related feature. Enforces OWASP Top 10 protections and Alpha AI security standards."
---

# Security Best Practices

This skill enforces comprehensive security standards across all Alpha AI projects. Every code change touching authentication, authorization, user input, secrets, HTTP headers, or any security-sensitive surface MUST comply with these rules.

---

## 1. Authentication & Authorization

### 1.1 Token Storage
- JWT MUST be stored in HTTP-only cookies (NEVER localStorage/sessionStorage)
- Set `Secure` flag on all auth cookies (HTTPS only)
- Set `SameSite=Lax` or `SameSite=Strict` on auth cookies
- Domain-scoped cookies only (no wildcard domains)

### 1.2 Token Lifetimes
- Access tokens: 30 minutes maximum
- Refresh tokens: 7 days maximum, rotated on each use
- One-time-use tokens (email verify, password reset): 15 minutes maximum
- API keys: 90 days maximum, with rotation reminders

### 1.3 Token Rotation Pattern
```python
# REQUIRED: Refresh token rotation implementation
async def rotate_refresh_token(old_refresh_token: str) -> TokenPair:
    """
    1. Validate the old refresh token
    2. Check if it has been used before (replay detection)
    3. Invalidate the old refresh token immediately
    4. Issue a new access token + new refresh token
    5. Store the new refresh token hash in Redis
    """
    payload = verify_refresh_token(old_refresh_token)

    # Replay detection: if token already used, revoke ALL user tokens
    if await redis.sismember(f"used_refresh_tokens:{payload['sub']}", old_refresh_token):
        await revoke_all_user_tokens(payload["sub"])
        raise SecurityException("Refresh token replay detected")

    # Mark old token as used
    await redis.sadd(f"used_refresh_tokens:{payload['sub']}", old_refresh_token)
    await redis.expire(f"used_refresh_tokens:{payload['sub']}", 7 * 86400)

    # Issue new pair
    new_access = create_access_token(subject=payload["sub"], expires_minutes=30)
    new_refresh = create_refresh_token(subject=payload["sub"], expires_days=7)

    return TokenPair(access_token=new_access, refresh_token=new_refresh)
```

### 1.4 CSRF Protection
- Double-submit cookie pattern on ALL state-changing endpoints (POST, PUT, PATCH, DELETE)
- Generate a random CSRF token per session
- Send token in both a cookie and a custom header (`X-CSRF-Token`)
- Server validates that cookie value matches header value
```python
# REQUIRED: CSRF middleware
from fastapi import Request, HTTPException

SAFE_METHODS = {"GET", "HEAD", "OPTIONS"}

@app.middleware("http")
async def csrf_protection(request: Request, call_next):
    if request.method not in SAFE_METHODS:
        cookie_token = request.cookies.get("csrf_token")
        header_token = request.headers.get("X-CSRF-Token")
        if not cookie_token or cookie_token != header_token:
            raise HTTPException(status_code=403, detail="CSRF validation failed")
    return await call_next(request)
```

### 1.5 Password Security
- Use bcrypt with cost factor >= 12 (NEVER md5, sha1, sha256 for passwords)
- Minimum password length: 10 characters
- Check against breached password databases (HaveIBeenPwned API)
- Do NOT enforce complex character rules (NIST 800-63B compliant)
```python
# REQUIRED: Password hashing
from passlib.context import CryptContext

pwd_context = CryptContext(
    schemes=["bcrypt"],
    bcrypt__rounds=12,  # Minimum cost factor
    deprecated="auto",
)

def hash_password(password: str) -> str:
    if len(password) < 10:
        raise ValueError("Password must be at least 10 characters")
    return pwd_context.hash(password)

def verify_password(plain: str, hashed: str) -> bool:
    return pwd_context.verify(plain, hashed)
```

### 1.6 Rate Limiting
- Auth endpoints (login, register, password reset): 5 attempts per minute per IP
- API endpoints: 100 requests per minute per user
- Global rate limit: 1000 requests per minute per IP
- Use Redis-backed rate limiting (sliding window algorithm)
```python
# REQUIRED: Rate limiter for auth endpoints
from fastapi_limiter import FastAPILimiter
from fastapi_limiter.depends import RateLimiter

@app.post("/auth/login", dependencies=[Depends(RateLimiter(times=5, seconds=60))])
async def login(credentials: LoginRequest):
    ...
```

### 1.7 Logout & Token Blacklisting
- On logout, blacklist the access token in Redis with TTL = remaining token lifetime
- Invalidate the refresh token immediately
- Clear all auth cookies
```python
# REQUIRED: Token blacklisting
async def logout(access_token: str, refresh_token: str):
    # Decode to get expiry
    payload = decode_token(access_token, verify_exp=False)
    remaining_ttl = payload["exp"] - int(time.time())
    if remaining_ttl > 0:
        await redis.setex(f"blacklist:{access_token}", remaining_ttl, "1")
    # Invalidate refresh token
    await redis.delete(f"refresh:{refresh_token}")

# Check on every request
async def is_token_blacklisted(token: str) -> bool:
    return await redis.exists(f"blacklist:{token}")
```

### 1.8 Role-Based Access Control (RBAC)
- Check permissions on EVERY protected endpoint
- Use dependency injection for permission checks
- Principle of least privilege: default deny
- Separate roles: admin, editor, viewer, service_account
```python
# REQUIRED: RBAC dependency
from fastapi import Depends, HTTPException, Security

def require_role(*roles: str):
    async def role_checker(current_user: User = Depends(get_current_user)):
        if current_user.role not in roles:
            raise HTTPException(status_code=403, detail="Insufficient permissions")
        return current_user
    return role_checker

@app.delete("/admin/users/{user_id}", dependencies=[Depends(require_role("admin"))])
async def delete_user(user_id: int):
    ...
```

---

## 2. Input Validation

### 2.1 Backend Validation (Pydantic)
- ALWAYS validate request data with Pydantic models
- Define strict types (no implicit coercion)
- Set max lengths on all string fields
- Use regex validators for structured data (emails, phone numbers)
```python
# REQUIRED: Pydantic validation pattern
from pydantic import BaseModel, Field, validator, EmailStr
import re

class UserCreate(BaseModel):
    email: EmailStr
    username: str = Field(..., min_length=3, max_length=50, pattern=r"^[a-zA-Z0-9_-]+$")
    password: str = Field(..., min_length=10, max_length=128)

    @validator("password")
    def password_strength(cls, v):
        if len(v) < 10:
            raise ValueError("Password must be at least 10 characters")
        return v

    class Config:
        str_strip_whitespace = True
        str_max_length = 500  # Global max for any unspecified string
```

### 2.2 Frontend Validation (Zod)
- ALWAYS validate with Zod schemas before sending to API
- Mirror backend validation rules on the frontend
```typescript
// REQUIRED: Zod validation pattern
import { z } from "zod";

const UserCreateSchema = z.object({
  email: z.string().email("Invalid email address"),
  username: z.string().min(3).max(50).regex(/^[a-zA-Z0-9_-]+$/),
  password: z.string().min(10).max(128),
});

type UserCreate = z.infer<typeof UserCreateSchema>;
```

### 2.3 Authorization Decisions
- NEVER trust client input for authorization decisions
- Always re-validate ownership and permissions server-side
- Do NOT rely on hidden form fields or client-side role checks
```python
# WRONG: Trusting client-provided user_id
@app.put("/profile")
async def update_profile(data: ProfileUpdate):
    user = await db.get(User, data.user_id)  # BAD: client controls user_id
    ...

# CORRECT: Use authenticated user identity
@app.put("/profile")
async def update_profile(data: ProfileUpdate, current_user: User = Depends(get_current_user)):
    user = await db.get(User, current_user.id)  # GOOD: server-controlled identity
    ...
```

### 2.4 XSS Prevention
- Sanitize ALL HTML output using a whitelist-based sanitizer
- Use template engines with auto-escaping (Jinja2 auto-escape=True)
- For React: avoid `dangerouslySetInnerHTML` unless sanitized with DOMPurify
```typescript
// REQUIRED: If raw HTML is unavoidable
import DOMPurify from "dompurify";

function SafeHTML({ html }: { html: string }) {
  return <div dangerouslySetInnerHTML={{ __html: DOMPurify.sanitize(html) }} />;
}
```

### 2.5 SQL Injection Prevention
- Use parameterized queries ONLY (NEVER string concatenation/f-strings for SQL)
- Use ORM methods (SQLAlchemy) whenever possible
- For raw SQL, always use bound parameters
```python
# WRONG: SQL injection vulnerability
query = f"SELECT * FROM users WHERE email = '{email}'"  # NEVER DO THIS

# CORRECT: Parameterized query
from sqlalchemy import text
result = await db.execute(text("SELECT * FROM users WHERE email = :email"), {"email": email})

# CORRECT: ORM method
user = await db.execute(select(User).where(User.email == email))
```

### 2.6 File Upload Validation
- Validate file type by content inspection (magic bytes), NOT just extension
- Set maximum file size (10MB default, configurable)
- Store uploads outside web root or in object storage (S3)
- Generate random filenames (UUID), NEVER use user-provided filenames
- Scan for malware if handling untrusted files
```python
# REQUIRED: File upload validation
import magic
import uuid

ALLOWED_TYPES = {"image/jpeg", "image/png", "image/webp", "application/pdf"}
MAX_FILE_SIZE = 10 * 1024 * 1024  # 10MB

async def validate_upload(file: UploadFile) -> str:
    content = await file.read()
    if len(content) > MAX_FILE_SIZE:
        raise HTTPException(413, "File too large")

    mime = magic.from_buffer(content, mime=True)
    if mime not in ALLOWED_TYPES:
        raise HTTPException(415, f"Unsupported file type: {mime}")

    safe_filename = f"{uuid.uuid4()}.{mime.split('/')[-1]}"
    return safe_filename
```

### 2.7 SSRF Prevention
- Validate ALL user-provided URLs before making server-side requests
- Block private IP ranges (10.x, 172.16-31.x, 192.168.x, 127.x, 169.254.x)
- Block localhost and link-local addresses
- Use allowlists for external service URLs when possible
```python
# REQUIRED: URL validation for SSRF prevention
import ipaddress
from urllib.parse import urlparse
import socket

BLOCKED_RANGES = [
    ipaddress.ip_network("10.0.0.0/8"),
    ipaddress.ip_network("172.16.0.0/12"),
    ipaddress.ip_network("192.168.0.0/16"),
    ipaddress.ip_network("127.0.0.0/8"),
    ipaddress.ip_network("169.254.0.0/16"),
    ipaddress.ip_network("0.0.0.0/8"),
]

def validate_url(url: str) -> bool:
    parsed = urlparse(url)
    if parsed.scheme not in ("http", "https"):
        return False
    try:
        ip = ipaddress.ip_address(socket.gethostbyname(parsed.hostname))
        for blocked in BLOCKED_RANGES:
            if ip in blocked:
                return False
    except (socket.gaierror, ValueError):
        return False
    return True
```

---

## 3. Secrets Management

### 3.1 Core Rules
- NEVER hardcode secrets, API keys, passwords, or tokens in source code
- NEVER commit secrets to version control (even in "test" code)
- Use `.env` files for local development ONLY
- `.env` MUST be in `.gitignore` ALWAYS
- Use platform secrets management in CI/CD (GitHub Secrets, AWS SSM, Vault)

### 3.2 Environment Separation
- Use different secrets per environment (dev, staging, production)
- Production secrets MUST NOT be accessible from dev/staging
- Service accounts should have minimum required permissions per environment

### 3.3 Secret Rotation
- Rotate all secrets on a defined schedule (90 days maximum)
- Automate rotation where possible (AWS Secrets Manager auto-rotation)
- Invalidate old secrets immediately after rotation
- Have a documented incident response plan for secret leaks

### 3.4 Configuration Pattern
```python
# REQUIRED: Settings management with Pydantic
from pydantic_settings import BaseSettings
from functools import lru_cache

class Settings(BaseSettings):
    # Database
    DATABASE_URL: str
    DB_POOL_SIZE: int = 20

    # Auth
    JWT_SECRET_KEY: str
    JWT_ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30
    REFRESH_TOKEN_EXPIRE_DAYS: int = 7

    # Redis
    REDIS_URL: str = "redis://localhost:6379"

    # CORS
    ALLOWED_ORIGINS: list[str] = ["http://localhost:3000"]

    # External APIs
    OPENAI_API_KEY: str = ""

    class Config:
        env_file = ".env"
        case_sensitive = True

@lru_cache()
def get_settings() -> Settings:
    return Settings()
```

### 3.5 Pre-commit Secret Detection
```yaml
# REQUIRED: .pre-commit-config.yaml entry
repos:
  - repo: https://github.com/Yelp/detect-secrets
    rev: v1.4.0
    hooks:
      - id: detect-secrets
        args: ['--baseline', '.secrets.baseline']
```

---

## 4. HTTP Security Headers

### 4.1 Required Security Headers Middleware
```python
# REQUIRED: Security headers middleware for every FastAPI application
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from starlette.middleware.base import BaseHTTPMiddleware

app = FastAPI()

# CORS Configuration - NEVER use ["*"] in production
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.ALLOWED_ORIGINS,  # Explicit origins only
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE"],
    allow_headers=["Content-Type", "X-CSRF-Token", "Authorization"],
)

@app.middleware("http")
async def security_headers(request, call_next):
    response = await call_next(request)
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["X-Frame-Options"] = "DENY"
    response.headers["X-XSS-Protection"] = "1; mode=block"
    response.headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains"
    response.headers["Content-Security-Policy"] = "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'"
    response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
    response.headers["Permissions-Policy"] = "camera=(), microphone=(), geolocation=()"
    response.headers["Cache-Control"] = "no-store, no-cache, must-revalidate"
    response.headers["Pragma"] = "no-cache"
    return response
```

### 4.2 CORS Rules
- NEVER use `allow_origins=["*"]` in production
- List explicit allowed origins
- Separate CORS configs for dev, staging, production
- Restrict `allow_methods` to only what is needed
- Restrict `allow_headers` to only what is needed

---

## 5. Dependency Security

### 5.1 Audit Schedule
- Run `pip-audit` on every CI pipeline run
- Run `npm audit` on every CI pipeline run
- Fail the build on HIGH or CRITICAL vulnerabilities
- Review MEDIUM vulnerabilities weekly

### 5.2 Version Pinning
- Pin ALL dependency versions in requirements.txt and package.json
- Use lock files (poetry.lock, package-lock.json) and commit them
- Use hash verification for Python packages (`pip install --require-hashes`)

### 5.3 Automated Updates
- Use Dependabot or Renovate for automated dependency PRs
- Auto-merge patch updates that pass CI
- Manually review minor and major updates
```yaml
# REQUIRED: .github/dependabot.yml
version: 2
updates:
  - package-ecosystem: "pip"
    directory: "/"
    schedule:
      interval: "weekly"
    open-pull-requests-limit: 10
  - package-ecosystem: "npm"
    directory: "/frontend"
    schedule:
      interval: "weekly"
    open-pull-requests-limit: 10
  - package-ecosystem: "docker"
    directory: "/"
    schedule:
      interval: "weekly"
```

---

## 6. Docker Security

### 6.1 Container Hardening
- Run as non-root user in ALL containers
- Use read-only filesystem (`read_only: true`) where possible
- NEVER run privileged containers
- Drop ALL capabilities, add back only what is needed
- Scan images with Trivy in CI pipeline
```dockerfile
# REQUIRED: Non-root user pattern
FROM python:3.11-slim

RUN groupadd -r appuser && useradd -r -g appuser -d /app -s /sbin/nologin appuser

WORKDIR /app
COPY --chown=appuser:appuser . .

USER appuser

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

### 6.2 Image Scanning
```yaml
# REQUIRED: Trivy scan in CI
- name: Scan Docker image
  uses: aquasecurity/trivy-action@master
  with:
    image-ref: ${{ env.IMAGE_NAME }}
    format: 'sarif'
    severity: 'CRITICAL,HIGH'
    exit-code: '1'
```

---

## 7. Logging & Monitoring

### 7.1 What to Log
- All authentication events (login success, login failure, logout, token refresh)
- All authorization failures (403 responses)
- All admin/privileged actions
- Input validation failures
- Rate limit hits
- External API errors

### 7.2 What NEVER to Log
- Passwords (plain or hashed)
- Access tokens or refresh tokens
- Credit card numbers or financial data
- Social Security numbers or government IDs
- Personal health information
- Full request bodies containing PII

### 7.3 Structured Logging Pattern
```python
# REQUIRED: Structured security event logging
import structlog

logger = structlog.get_logger()

async def log_auth_event(event_type: str, user_id: str, ip: str, success: bool, **kwargs):
    logger.info(
        "auth_event",
        event_type=event_type,
        user_id=user_id,
        ip_address=ip,
        success=success,
        **kwargs,
    )

# Usage
await log_auth_event("login", user.id, request.client.host, success=True)
await log_auth_event("login", email, request.client.host, success=False, reason="invalid_password")
```

### 7.4 Alerting Rules
- Alert on: 5+ failed logins from same IP within 5 minutes
- Alert on: privilege escalation attempts
- Alert on: access from unusual geographic locations
- Alert on: bulk data export requests
- Alert on: admin account creation outside normal workflow
- Alert on: dependency vulnerability scan failures

---

## 8. API Security

### 8.1 API Versioning
- Always version APIs (`/api/v1/`, `/api/v2/`)
- Deprecate old versions with advance notice (minimum 6 months)
- Return `Sunset` header on deprecated endpoints

### 8.2 Error Handling
- NEVER expose stack traces in production error responses
- Use generic error messages for auth failures ("Invalid credentials", NOT "User not found" vs "Wrong password")
- Return consistent error format
```python
# REQUIRED: Secure error responses
from fastapi import HTTPException

# WRONG: Information leakage
raise HTTPException(400, "User with email john@example.com not found")

# CORRECT: Generic error
raise HTTPException(401, "Invalid credentials")
```

### 8.3 Request Size Limits
- Set maximum request body size (1MB default for API, 10MB for file uploads)
- Set maximum URL length (2048 characters)
- Set maximum header size (8KB)
```python
# REQUIRED: Request size limits
from starlette.middleware.base import BaseHTTPMiddleware

class RequestSizeLimitMiddleware(BaseHTTPMiddleware):
    def __init__(self, app, max_body_size: int = 1_048_576):  # 1MB
        super().__init__(app)
        self.max_body_size = max_body_size

    async def dispatch(self, request, call_next):
        content_length = request.headers.get("content-length")
        if content_length and int(content_length) > self.max_body_size:
            raise HTTPException(413, "Request body too large")
        return await call_next(request)

app.add_middleware(RequestSizeLimitMiddleware, max_body_size=1_048_576)
```

---

## 9. Data Protection

### 9.1 Encryption
- Encrypt sensitive data at rest (AES-256)
- Use TLS 1.2+ for all data in transit
- Hash personally identifiable information where possible (anonymization)

### 9.2 Data Minimization
- Collect only the data you need
- Purge data on defined retention schedules
- Anonymize data for analytics and testing
- Never copy production data to dev/staging without anonymization

---

## 10. Security Checklist for Code Reviews

Every PR touching security-sensitive code MUST verify:

- [ ] JWT stored in HTTP-only cookies (not localStorage)
- [ ] Token lifetimes within limits (30min access, 7d refresh)
- [ ] CSRF protection on state-changing endpoints
- [ ] Input validated with Pydantic/Zod
- [ ] No SQL injection vectors (parameterized queries only)
- [ ] No XSS vectors (output sanitized)
- [ ] No hardcoded secrets
- [ ] Proper error messages (no information leakage)
- [ ] Rate limiting on sensitive endpoints
- [ ] RBAC checks on protected endpoints
- [ ] Security headers present
- [ ] Audit logging for auth events
- [ ] Dependencies scanned for vulnerabilities
- [ ] File uploads validated by content type
- [ ] User-provided URLs validated for SSRF

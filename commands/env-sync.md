---
description: "Validate environment variable parity across dev/staging/prod, detect config drift, and manage encrypted secrets. Usage: /env-sync [check | diff | encrypt | rotate | init]"
---

# Environment Sync & Configuration Management

Action: **$ARGUMENTS** (default: `check`)

Parse $ARGUMENTS:
- `check` — Audit all .env files for parity and missing variables
- `diff <env1> <env2>` — Compare two environment files side by side
- `encrypt` — Encrypt sensitive .env values using age/sops
- `rotate` — Guide through secret rotation for all services
- `init` — Generate .env.example and environment templates
- No argument = `check`

---

## Step 0: Discover Environment Files

```bash
echo "=== Environment Files ==="
find . -maxdepth 3 -name ".env*" -not -path "*/node_modules/*" -not -path "*/.git/*" -not -path "*/.venv/*" 2>/dev/null | sort

echo ""
echo "=== Git-tracked .env Files (DANGER) ==="
git ls-files | grep -i '\.env' 2>/dev/null || echo "None (good)"

echo ""
echo "=== .gitignore Coverage ==="
grep -n "env" .gitignore 2>/dev/null || echo "WARNING: No .env entries in .gitignore"

echo ""
echo "=== Docker Compose env_file References ==="
grep -rn "env_file" docker-compose*.yml docker/docker-compose*.yml 2>/dev/null | head -10

echo ""
echo "=== Kubernetes Secrets/ConfigMaps ==="
find . -maxdepth 4 -name "*.yaml" -o -name "*.yml" 2>/dev/null | xargs grep -l "kind: Secret\|kind: ConfigMap" 2>/dev/null | head -10
```

Build a map of all environment files and their purposes:
- `.env` → Local development
- `.env.development` → Development overrides
- `.env.staging` → Staging environment
- `.env.production` → Production environment
- `.env.test` → Test environment
- `.env.example` → Template (should be committed)

---

## Step 1: Parse All Environment Files

For each `.env*` file found, parse into a structured map:

```
{
  "file": ".env",
  "variables": {
    "DATABASE_URL": { "value": "mysql://...", "has_value": true, "is_secret": true },
    "DEBUG": { "value": "true", "has_value": true, "is_secret": false },
    ...
  }
}
```

**Secret detection heuristics** — mark as `is_secret: true` if the variable name contains:
- `PASSWORD`, `PASSWD`, `PWD`
- `SECRET`, `KEY` (but not `PUBLIC_KEY`)
- `TOKEN` (but not `TOKEN_EXPIRY`)
- `API_KEY`, `APIKEY`
- `PRIVATE`
- `CREDENTIALS`, `CRED`
- `CONNECTION_STRING`, `DATABASE_URL`, `MONGO_URI`, `REDIS_URL`

---

## Step 2: Environment Parity Check (Action: `check`)

Compare all environment files against `.env.example` (or `.env` if no example exists).

### 2a: Missing Variables Report

For each environment file, check:
1. **Variables in .env.example but missing in this file** → `MISSING`
2. **Variables in this file but not in .env.example** → `EXTRA` (may be intentional)
3. **Variables with empty values** → `EMPTY`
4. **Variables with placeholder values** (e.g., `CHANGE_ME`, `your_`, `xxx`, `TODO`) → `PLACEHOLDER`

### 2b: Value Consistency Checks

Flag inconsistencies:
- `DEBUG=true` in `.env.production` → **CRITICAL**: Debug mode in production
- `LOG_LEVEL=debug` in `.env.production` → **WARNING**: Verbose logging in production
- Different `JWT_ALGORITHM` values across environments → **ERROR**: Auth will break
- Different `CORS_ORIGINS` that don't match expected domains → **WARNING**
- `SENTRY_DSN` empty in production → **WARNING**: No error tracking

### 2c: Security Checks

- Secrets with identical values across dev/staging/prod → **HIGH**: Should be different per environment
- Production secrets that look like test values (contain `test`, `dev`, `local`, `example`) → **CRITICAL**
- Any `.env` file tracked by git → **CRITICAL**
- `.env` file with world-readable permissions → **HIGH**
- `.env.production` file present on developer machines → **WARNING**

### 2d: Output Report

```
╔══════════════════════════════════════════════════════════════╗
║     ENVIRONMENT SYNC REPORT                                  ║
╠══════════════════════════════════════════════════════════════╣
║                                                              ║
║  Files Analyzed: [N]                                         ║
║  Reference:      .env.example ([N] variables)                ║
║                                                              ║
║  ┌──────────────────┬────────┬────────┬─────────┬──────────┐ ║
║  │ File             │ Missing│ Extra  │ Empty   │ Placeholder║
║  ├──────────────────┼────────┼────────┼─────────┼──────────┤ ║
║  │ .env             │   0    │   2    │   1     │    0     │ ║
║  │ .env.staging     │   3    │   0    │   0     │    2     │ ║
║  │ .env.production  │   1    │   0    │   0     │    0     │ ║
║  └──────────────────┴────────┴────────┴─────────┴──────────┘ ║
║                                                              ║
║  Issues Found:                                               ║
║    CRITICAL: [N]                                             ║
║    HIGH:     [N]                                             ║
║    WARNING:  [N]                                             ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
```

Then list each issue with details:
```
CRITICAL  .env.staging: DATABASE_URL contains 'localhost' (should be staging DB)
CRITICAL  .env.production: DEBUG=true (must be false in production)
HIGH      JWT_SECRET identical in .env and .env.staging (use unique secrets)
WARNING   .env.production: SENTRY_DSN is empty (no error tracking)
MISSING   .env.staging: REDIS_URL (required, present in .env.example)
MISSING   .env.staging: S3_BUCKET (required, present in .env.example)
```

---

## Step 3: Environment Diff (Action: `diff <env1> <env2>`)

When the user runs `/env-sync diff .env .env.staging`, show a side-by-side comparison:

```
╔═══════════════════════════════════════════════════════════════════════╗
║  DIFF: .env  ←→  .env.staging                                       ║
╠═══════════════════════════════════════════════════════════════════════╣
║                                                                       ║
║  Variable              │ .env                  │ .env.staging          ║
║  ──────────────────────┼───────────────────────┼─────────────────────  ║
║  DATABASE_URL          │ mysql://localhost/app  │ mysql://stg-db/app   ║
║  REDIS_URL             │ redis://localhost      │ redis://stg-redis    ║
║  DEBUG                 │ true                   │ false                ║
║  LOG_LEVEL             │ debug                  │ info                 ║
║  JWT_SECRET            │ dev-secret-key         │ ██████████ (hidden)  ║
║  SENTRY_DSN            │ (empty)                │ https://sentry.io/.. ║
║  ──────────────────────┼───────────────────────┼─────────────────────  ║
║  S3_BUCKET             │ dev-uploads            │ ⚠️ MISSING           ║
║  FEATURE_NEW_UI        │ true                   │ ⚠️ MISSING           ║
║  ──────────────────────┼───────────────────────┼─────────────────────  ║
║  STG_ONLY_VAR          │ ⚠️ MISSING             │ some-value           ║
║                                                                       ║
╚═══════════════════════════════════════════════════════════════════════╝
```

**Important:** NEVER display actual secret values in the diff. Mask secrets with `██████████ (hidden)`. Only show whether they are set/empty/missing.

---

## Step 4: Generate .env.example (Action: `init`)

If `.env.example` doesn't exist (or needs updating), generate one from the union of all `.env*` files:

```bash
# .env.example — Generated by Cortex /env-sync
# Copy this to .env and fill in real values
# DO NOT commit .env files with real values

# ─── Application ───
APP_NAME=your-app-name
APP_ENV=development
DEBUG=true
LOG_LEVEL=debug
PORT=8000

# ─── Database (MySQL) ───
MYSQL_HOST=localhost
MYSQL_PORT=3306
MYSQL_USER=root
MYSQL_PASSWORD=CHANGE_ME
MYSQL_DATABASE=your_app_db
DATABASE_URL=mysql://root:CHANGE_ME@localhost:3306/your_app_db

# ─── MongoDB ───
MONGO_URI=mongodb://localhost:27017
MONGO_DATABASE=your_app_db

# ─── Redis ───
REDIS_URL=redis://localhost:6379
REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_PASSWORD=

# ─── Authentication ───
JWT_SECRET=CHANGE_ME_use_openssl_rand_hex_32
JWT_ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=30
REFRESH_TOKEN_EXPIRE_DAYS=7

# ─── CORS ───
CORS_ORIGINS=http://localhost:3000

# ─── Email ───
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=CHANGE_ME
SMTP_PASSWORD=CHANGE_ME
EMAIL_FROM=noreply@yourapp.com

# ─── Storage ───
S3_BUCKET=CHANGE_ME
S3_REGION=ap-south-1
S3_ACCESS_KEY=CHANGE_ME
S3_SECRET_KEY=CHANGE_ME

# ─── Payments ───
RAZORPAY_KEY_ID=CHANGE_ME
RAZORPAY_KEY_SECRET=CHANGE_ME

# ─── Monitoring ───
SENTRY_DSN=
POSTHOG_API_KEY=

# ─── AI/LLM ───
OPENAI_API_KEY=CHANGE_ME
ANTHROPIC_API_KEY=CHANGE_ME
LITELLM_MASTER_KEY=CHANGE_ME
```

Also ensure `.gitignore` contains:
```
.env
.env.local
.env.development
.env.staging
.env.production
.env.*.local
!.env.example
```

---

## Step 5: Secret Rotation Guide (Action: `rotate`)

Walk the user through rotating secrets for all services:

### 5a: Identify All Secrets

Read all `.env*` files and list every secret variable:
```
Secrets found across all environments:

1. JWT_SECRET (used in: .env, .env.staging, .env.production)
2. MYSQL_PASSWORD (used in: .env, .env.staging, .env.production)
3. REDIS_PASSWORD (used in: .env.staging, .env.production)
4. RAZORPAY_KEY_SECRET (used in: .env, .env.staging, .env.production)
5. S3_SECRET_KEY (used in: .env, .env.staging, .env.production)
6. SMTP_PASSWORD (used in: .env, .env.staging, .env.production)
7. OPENAI_API_KEY (used in: .env, .env.staging, .env.production)
```

### 5b: Generate New Secrets

For each secret, suggest the rotation procedure:

```
╔══════════════════════════════════════════════════════════════╗
║     SECRET ROTATION GUIDE                                    ║
╠══════════════════════════════════════════════════════════════╣
║                                                              ║
║  1. JWT_SECRET                                               ║
║     Generate: openssl rand -hex 32                           ║
║     Impact:   All active sessions will be invalidated        ║
║     Steps:    Update .env → restart app → users re-login     ║
║                                                              ║
║  2. MYSQL_PASSWORD                                           ║
║     Generate: openssl rand -base64 24                        ║
║     Impact:   App will lose DB connection briefly             ║
║     Steps:    ALTER USER in MySQL → update .env → restart     ║
║     Command:  ALTER USER 'user'@'%' IDENTIFIED BY 'new_pw'; ║
║                                                              ║
║  3. REDIS_PASSWORD                                           ║
║     Generate: openssl rand -hex 16                           ║
║     Impact:   Cache connections drop, sessions cleared        ║
║     Steps:    CONFIG SET requirepass "new" → update .env      ║
║                                                              ║
║  4. RAZORPAY_KEY_SECRET                                      ║
║     Rotate:   Razorpay Dashboard → API Keys → Regenerate    ║
║     Impact:   Webhook verification will fail until updated    ║
║     Steps:    Regenerate on dashboard → update .env → restart ║
║                                                              ║
║  5. S3_SECRET_KEY                                            ║
║     Rotate:   AWS IAM → Create new access key → delete old   ║
║     Impact:   File uploads will fail briefly                  ║
║     Steps:    Create new key → update .env → restart → del   ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
```

### 5c: Rotation Checklist

For each environment (staging first, then production):

```markdown
## Secret Rotation Checklist — [environment]

- [ ] Generate new values for all secrets
- [ ] Update .env file with new values
- [ ] Update Kubernetes secrets / Docker secrets (if applicable)
- [ ] Restart application services
- [ ] Verify health endpoint returns 200
- [ ] Verify authentication flow works (login/logout/refresh)
- [ ] Verify payment webhook validation
- [ ] Verify file upload/download
- [ ] Monitor error rates for 30 minutes
- [ ] Delete old API keys/access keys from provider dashboards
- [ ] Update DR_RUNBOOK.md with rotation date
```

---

## Step 6: Encryption Setup (Action: `encrypt`)

Guide through encrypting `.env` files using Mozilla SOPS or age:

### 6a: Check Prerequisites

```bash
echo "=== Checking encryption tools ==="
command -v sops && sops --version || echo "sops not found (install: brew install sops)"
command -v age && age --version || echo "age not found (install: brew install age)"
command -v age-keygen 2>/dev/null || echo "age-keygen not found"
```

### 6b: Generate Encryption Key

```bash
# Generate age key pair
age-keygen -o keys.txt 2>&1
# Extract public key
AGE_PUBLIC_KEY=$(grep "public key:" keys.txt | cut -d: -f2 | tr -d ' ')
echo "Public key: ${AGE_PUBLIC_KEY}"
echo ""
echo "IMPORTANT: Store keys.txt securely (password manager, NOT in git)"
```

### 6c: Create SOPS Configuration

Generate `.sops.yaml`:
```yaml
creation_rules:
  - path_regex: \.env\.production$
    age: >-
      age1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
  - path_regex: \.env\.staging$
    age: >-
      age1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
  - path_regex: \.env$
    age: >-
      age1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

### 6d: Encrypt Existing Files

```bash
# Encrypt production secrets
sops --encrypt --in-place .env.production

# Encrypt staging secrets
sops --encrypt --in-place .env.staging

# To edit encrypted files:
# sops .env.production

# To decrypt for deployment:
# sops --decrypt .env.production > /tmp/.env.production
```

---

## Step 7: Startup Validation

Generate code that validates required environment variables at application startup.

### Python (FastAPI):
```python
# app/core/config.py
from pydantic_settings import BaseSettings
from pydantic import field_validator
from typing import Optional

class Settings(BaseSettings):
    # Required — app will not start without these
    APP_NAME: str
    DATABASE_URL: str
    JWT_SECRET: str
    REDIS_URL: str

    # Optional with defaults
    DEBUG: bool = False
    LOG_LEVEL: str = "info"
    PORT: int = 8000

    # Conditional — required in production
    SENTRY_DSN: Optional[str] = None

    @field_validator("JWT_SECRET")
    @classmethod
    def jwt_secret_not_default(cls, v):
        if v in ("CHANGE_ME", "secret", "dev-secret", "test"):
            raise ValueError("JWT_SECRET must be changed from default value")
        if len(v) < 32:
            raise ValueError("JWT_SECRET must be at least 32 characters")
        return v

    class Config:
        env_file = ".env"
        case_sensitive = True

settings = Settings()
```

### NestJS:
```typescript
// src/config/env.validation.ts
import { plainToInstance } from 'class-transformer';
import { IsString, IsNumber, IsOptional, MinLength, validateSync } from 'class-validator';

class EnvironmentVariables {
  @IsString()
  DATABASE_URL: string;

  @IsString()
  @MinLength(32)
  JWT_SECRET: string;

  @IsString()
  REDIS_URL: string;

  @IsNumber()
  @IsOptional()
  PORT: number = 8000;
}

export function validate(config: Record<string, unknown>) {
  const validated = plainToInstance(EnvironmentVariables, config, {
    enableImplicitConversion: true,
  });
  const errors = validateSync(validated, { skipMissingProperties: false });
  if (errors.length > 0) {
    throw new Error(`Config validation failed: ${errors.toString()}`);
  }
  return validated;
}
```

---

## Step 8: Output Summary

```
╔══════════════════════════════════════════════════════════════╗
║     ENVIRONMENT SYNC COMPLETE                                ║
╠══════════════════════════════════════════════════════════════╣
║                                                              ║
║  Files Analyzed:    [N] environment files                    ║
║  Variables Tracked: [N] unique variables                     ║
║  Secrets Detected:  [N] sensitive values                     ║
║                                                              ║
║  Issues:                                                     ║
║    CRITICAL: [N] (must fix before deployment)                ║
║    HIGH:     [N] (fix within this sprint)                    ║
║    WARNING:  [N] (review and address)                        ║
║                                                              ║
║  Actions Taken:                                              ║
║    [✅/⚠️] .env.example generated/updated                    ║
║    [✅/⚠️] .gitignore updated                                ║
║    [✅/⚠️] Startup validation code generated                 ║
║    [✅/⚠️] Encryption configured                             ║
║                                                              ║
║  Next Steps:                                                 ║
║    1. Fix all CRITICAL issues listed above                   ║
║    2. Run /env-sync rotate to rotate stale secrets           ║
║    3. Run /env-sync encrypt for production files             ║
║    4. Add startup validation to your app entrypoint          ║
╚══════════════════════════════════════════════════════════════╝
```

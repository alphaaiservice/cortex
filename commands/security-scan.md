---
description: "Run comprehensive security audit: SAST, dependency vulnerabilities, secret detection, OWASP Top 10 checks, and Docker security. Usage: /security-scan [--full] [--fix]"
---

# Comprehensive Security Audit

You are a senior application security engineer performing a thorough security audit of this codebase.

**Arguments**: $ARGUMENTS

Parse flags from arguments:
- `--full` = Run all steps including deep git history scan and Docker image scan (slower)
- `--fix` = Auto-remediate findings that can be safely fixed
- No flags = Run standard scan (Steps 1-7)

---

## Step 0: Project Discovery

Before scanning, understand what we are working with.

```bash
echo "=== Project Root ==="
pwd

echo "=== Languages Detected ==="
find . -maxdepth 3 -type f \( -name "*.py" -o -name "*.js" -o -name "*.ts" -o -name "*.tsx" -o -name "*.jsx" -o -name "*.go" -o -name "*.rs" -o -name "*.java" \) 2>/dev/null | sed 's/.*\.//' | sort | uniq -c | sort -rn

echo "=== Package Managers ==="
ls -la package.json yarn.lock package-lock.json pnpm-lock.yaml requirements.txt Pipfile pyproject.toml go.mod Cargo.toml Gemfile 2>/dev/null

echo "=== Docker Files ==="
find . -maxdepth 3 -name "Dockerfile*" -o -name "docker-compose*.yml" -o -name "docker-compose*.yaml" 2>/dev/null

echo "=== Config Files ==="
find . -maxdepth 3 -name ".env*" -o -name "*.conf" -o -name "*.cfg" -o -name "*.ini" -o -name "settings.py" -o -name "config.py" 2>/dev/null

echo "=== Git Status ==="
git status --short 2>/dev/null
git remote -v 2>/dev/null
```

Use the output to determine which scans are applicable (Python, Node.js, Docker, etc.) and tailor each step accordingly.

Initialize a findings tracker. Track every finding as:
```
{severity: "CRITICAL|HIGH|MEDIUM|LOW|INFO", category: "...", title: "...", file: "...", line: N, description: "...", remediation: "..."}
```

---

## Step 1: Secret Detection

This is the highest-priority scan. Leaked secrets can cause immediate damage.

Use Agent tool (mode = "bypassPermissions") to run the following sub-scans in parallel:

### 1A: Hardcoded API Keys and Tokens

Search the entire codebase for hardcoded secrets using these patterns. Use Grep for each pattern.

**AWS Credentials:**
```
Pattern: AKIA[0-9A-Z]{16}
Pattern: aws_secret_access_key\s*=\s*['\"][A-Za-z0-9/+=]{40}
```

**Google Cloud:**
```
Pattern: AIza[0-9A-Za-z\-_]{35}
Pattern: [0-9]+-[0-9A-Za-z_]{32}\.apps\.googleusercontent\.com
Pattern: \"type\":\s*\"service_account\"
```

**GitHub/GitLab Tokens:**
```
Pattern: ghp_[0-9a-zA-Z]{36}
Pattern: gho_[0-9a-zA-Z]{36}
Pattern: github_pat_[0-9a-zA-Z]{22}_[0-9a-zA-Z]{59}
Pattern: glpat-[0-9a-zA-Z\-_]{20,}
```

**Stripe/Razorpay:**
```
Pattern: sk_live_[0-9a-zA-Z]{24,}
Pattern: pk_live_[0-9a-zA-Z]{24,}
Pattern: sk_test_[0-9a-zA-Z]{24,}
Pattern: rzp_live_[0-9a-zA-Z]{14,}
Pattern: rzp_test_[0-9a-zA-Z]{14,}
```

**OpenAI/Anthropic/LLM Keys:**
```
Pattern: sk-[0-9a-zA-Z]{20,}
Pattern: sk-ant-[0-9a-zA-Z\-]{20,}
Pattern: sk-proj-[0-9a-zA-Z]{20,}
```

**JWT and Generic Secrets:**
```
Pattern: (?i)(jwt[_-]?secret|jwt[_-]?key)\s*[:=]\s*['\"][^'\"]{8,}
Pattern: (?i)(password|passwd|pwd)\s*[:=]\s*['\"][^'\"]{4,}
Pattern: (?i)(secret[_-]?key|api[_-]?key|apikey|access[_-]?key)\s*[:=]\s*['\"][^'\"]{8,}
Pattern: (?i)private[_-]?key\s*[:=]\s*['\"]
Pattern: (?i)bearer\s+[a-zA-Z0-9\-._~+/]+=*
```

**Database Connection Strings:**
```
Pattern: (?i)(mysql|postgres|postgresql|mongodb|redis|amqp):\/\/[^\s'\"]{10,}
Pattern: (?i)database_url\s*[:=]\s*['\"][^\s'\"]{10,}
```

**Important:** Exclude false positives:
- Skip `node_modules/`, `.git/`, `venv/`, `__pycache__/`, `.next/`, `dist/`, `build/`
- Skip `*.md` files that document patterns (like this security-scan file itself)
- Skip `*.example`, `*.sample`, `*.template` files that contain placeholders
- Skip test fixtures that contain dummy/fake keys
- Verify each hit by reading 5 lines of context around the match

For each confirmed secret, record as **CRITICAL** severity finding.

### 1B: Environment File Audit

```bash
echo "=== .env Files Present ==="
find . -name ".env" -o -name ".env.local" -o -name ".env.production" -o -name ".env.staging" -o -name ".env.development" 2>/dev/null | grep -v node_modules | grep -v .git

echo "=== .gitignore Coverage ==="
cat .gitignore 2>/dev/null | grep -i env

echo "=== .env Files Tracked by Git ==="
git ls-files | grep -i '\.env' 2>/dev/null

echo "=== .env Files in Git History ==="
git log --all --diff-filter=A --name-only --format="" -- "*.env" "*.env.*" 2>/dev/null | sort -u
```

**Checks:**
- Any `.env` file tracked by git = **CRITICAL**
- `.env` not in `.gitignore` = **HIGH**
- `.env.example` contains real values (not placeholders) = **HIGH**
- `.env` files with overly permissive file permissions = **MEDIUM**

### 1C: Git History Secret Scan (only with --full flag)

If `--full` is in $ARGUMENTS:

```bash
# Search recent git history for accidentally committed secrets
# Look in last 100 commits for common secret patterns
git log -p -100 --all -- . 2>/dev/null | grep -iE "(AKIA|sk_live|sk_test|sk-|ghp_|glpat-|rzp_live|password\s*=\s*['\"]|api_key\s*=\s*['\"])" | head -50
```

Any secrets found in git history = **CRITICAL** (secrets remain even after deletion from working tree).

**Remediation:** If secrets found in history, recommend `git-filter-repo` or BFG Repo Cleaner, and immediate key rotation.

### 1D: Certificate and Key File Detection

```bash
# Check for private keys and certificates committed to repo
find . -maxdepth 5 \( -name "*.pem" -o -name "*.key" -o -name "*.p12" -o -name "*.pfx" -o -name "*.jks" -o -name "*.keystore" -o -name "id_rsa" -o -name "id_ed25519" \) -not -path "*/node_modules/*" -not -path "*/.git/*" 2>/dev/null

# Check if they are tracked by git
git ls-files -- "*.pem" "*.key" "*.p12" "*.pfx" "*.jks" "*.keystore" 2>/dev/null
```

Private keys tracked by git = **CRITICAL**.

---

## Step 2: Dependency Vulnerability Scan

Use Agent tool (mode = "bypassPermissions") to run applicable scans in parallel:

### 2A: Python Dependencies

```bash
# Check if Python project
if [ -f "requirements.txt" ] || [ -f "pyproject.toml" ] || [ -f "Pipfile" ]; then
    echo "=== Python Project Detected ==="

    # Try pip-audit first (preferred)
    if command -v pip-audit &>/dev/null; then
        echo "--- pip-audit ---"
        pip-audit --format json 2>&1 || pip-audit 2>&1
    fi

    # Fallback to safety
    if command -v safety &>/dev/null; then
        echo "--- safety check ---"
        safety check --json 2>&1 || safety check 2>&1
    fi

    # Check for pinned versions
    echo "--- Unpinned Dependencies ---"
    if [ -f "requirements.txt" ]; then
        grep -vE "^#|^$|==|~=" requirements.txt 2>/dev/null | head -20
    fi

    # Check for known vulnerable package versions
    echo "--- Checking Critical Packages ---"
    pip list --format=json 2>/dev/null | python3 -c "
import sys, json
try:
    pkgs = json.load(sys.stdin)
    critical = {'django': '4.2', 'flask': '2.3', 'requests': '2.31', 'cryptography': '41.0', 'pyjwt': '2.8', 'sqlalchemy': '2.0'}
    for pkg in pkgs:
        name = pkg['name'].lower()
        if name in critical:
            print(f'{name}=={pkg[\"version\"]} (minimum recommended: >={critical[name]})')
except: pass
" 2>/dev/null
fi
```

### 2B: Node.js Dependencies

```bash
# Check if Node.js project
if [ -f "package.json" ]; then
    echo "=== Node.js Project Detected ==="

    # npm audit
    if [ -f "package-lock.json" ]; then
        echo "--- npm audit ---"
        npm audit --json 2>&1 | head -200
    fi

    # yarn audit
    if [ -f "yarn.lock" ]; then
        echo "--- yarn audit ---"
        yarn audit --json 2>&1 | head -200
    fi

    # pnpm audit
    if [ -f "pnpm-lock.yaml" ]; then
        echo "--- pnpm audit ---"
        pnpm audit --json 2>&1 | head -200
    fi

    # Check for outdated critical packages
    echo "--- Outdated Packages ---"
    npm outdated 2>&1 | head -30
fi
```

### 2C: Docker Image Scan (only with --full flag)

If `--full` is in $ARGUMENTS and Dockerfiles exist:

```bash
# Scan Docker images with trivy if available
if command -v trivy &>/dev/null; then
    for dockerfile in $(find . -name "Dockerfile*" -maxdepth 3 2>/dev/null); do
        image_name=$(basename $(dirname $dockerfile))
        echo "--- Scanning image from $dockerfile ---"
        # Build and scan
        docker build -f "$dockerfile" -t "security-scan-${image_name}:latest" . 2>/dev/null
        trivy image --severity HIGH,CRITICAL "security-scan-${image_name}:latest" 2>&1
    done
elif command -v grype &>/dev/null; then
    echo "--- Using grype for image scan ---"
    for dockerfile in $(find . -name "Dockerfile*" -maxdepth 3 2>/dev/null); do
        echo "Scanning: $dockerfile"
        grype dir:. --only-fixed --fail-on high 2>&1
    done
else
    echo "WARNING: Neither trivy nor grype found. Install with: brew install trivy"
fi
```

**For each vulnerability found, record:**
- CVE ID
- Severity (Critical / High / Medium / Low)
- Affected package and version
- Fixed version (if available)
- Whether it is directly exploitable in this project

---

## Step 3: SAST (Static Application Security Testing)

Use Agent tool (mode = "bypassPermissions") to run the following checks in parallel. Each check uses Grep to find vulnerable patterns.

### 3A: SQL Injection

Search for raw SQL queries without parameterization.

**Python patterns to flag:**
```
Pattern: \.execute\(\s*f['\"]
Pattern: \.execute\(\s*['\"].*%s.*['\"].*%
Pattern: \.execute\(\s*['\"].*\+\s*
Pattern: \.execute\(\s*['\"].*\.format\(
Pattern: cursor\.execute\(.*\+
Pattern: text\(\s*f['\"]
Pattern: \.raw\(\s*f['\"]
```

**Node.js patterns to flag:**
```
Pattern: \.query\(\s*`.*\$\{
Pattern: \.query\(\s*['\"].*\+\s*
Pattern: \.exec\(\s*['\"].*\+\s*
Pattern: \.raw\(\s*`.*\$\{
```

Severity: **HIGH** for any f-string or string concatenation in SQL queries.
Severity: **CRITICAL** if the concatenated value comes from request/user input.

### 3B: Command Injection

```
Pattern: os\.system\(
Pattern: os\.popen\(
Pattern: subprocess\.call\(.*shell\s*=\s*True
Pattern: subprocess\.run\(.*shell\s*=\s*True
Pattern: subprocess\.Popen\(.*shell\s*=\s*True
Pattern: eval\(
Pattern: exec\((?!utor)
Pattern: child_process\.exec\(
Pattern: child_process\.execSync\(
```

Severity: **CRITICAL** if user input flows into the command.
Severity: **HIGH** for any use of `shell=True` with subprocess.
Severity: **MEDIUM** for `eval()` / `exec()` usage even without direct user input.

### 3C: Cross-Site Scripting (XSS)

```
Pattern: innerHTML\s*=
Pattern: outerHTML\s*=
Pattern: document\.write\(
Pattern: dangerouslySetInnerHTML
Pattern: \|\s*safe\b
Pattern: \.html\(\s*
Pattern: v-html\s*=
Pattern: \{\{\{.*\}\}\}
Pattern: Markup\(
Pattern: \.format\(.*\)\s*\)  (in template context)
```

Severity: **HIGH** for `innerHTML` with dynamic content.
Severity: **MEDIUM** for `dangerouslySetInnerHTML` (React requires explicit opt-in, but still risky).
Severity: **HIGH** for Jinja2 `|safe` filter on user-controlled data.

### 3D: Path Traversal

```
Pattern: open\(.*request\.(args|form|data|json|values)
Pattern: os\.path\.join\(.*request\.
Pattern: send_file\(.*request\.
Pattern: send_from_directory\(.*request\.
Pattern: fs\.readFile\(.*req\.(body|params|query)
Pattern: fs\.readFileSync\(.*req\.
Pattern: \.\.\/
```

Severity: **HIGH** for any file operation using user-supplied paths without sanitization.

### 3E: Server-Side Request Forgery (SSRF)

```
Pattern: requests\.(get|post|put|delete|patch|head)\(.*request\.
Pattern: urllib\.request\.urlopen\(.*request\.
Pattern: httpx\.(get|post|put|delete)\(.*request\.
Pattern: aiohttp\.ClientSession\(\)\.get\(.*request\.
Pattern: fetch\(.*req\.(body|params|query)
Pattern: axios\.(get|post)\(.*req\.
Pattern: http\.get\(.*req\.
```

Severity: **HIGH** for any HTTP client call using user-controlled URLs.

### 3F: Insecure Deserialization

```
Pattern: pickle\.loads?\(
Pattern: pickle\.Unpickler\(
Pattern: yaml\.load\((?!.*Loader)
Pattern: yaml\.load\([^)]*\)  (without SafeLoader)
Pattern: marshal\.loads?\(
Pattern: shelve\.open\(
Pattern: unserialize\(
Pattern: JSON\.parse\(.*(?:req|request)
```

Severity: **CRITICAL** for `pickle.load` on untrusted data.
Severity: **HIGH** for `yaml.load` without `Loader=SafeLoader`.
Severity: **MEDIUM** for `marshal.loads`.

### 3G: Hardcoded JWT Secrets

```
Pattern: (?i)jwt\.encode\(.*['\"][a-zA-Z0-9]{8,}['\"]
Pattern: (?i)SECRET_KEY\s*=\s*['\"][^'\"]{4,}['\"]
Pattern: (?i)JWT_SECRET\s*=\s*['\"][^'\"]{4,}['\"]
Pattern: (?i)app\.secret_key\s*=\s*['\"]
```

Severity: **CRITICAL** for hardcoded JWT secrets in source code.
Note: Secrets should come from environment variables only.

### 3H: Missing Security Headers and CORS

Search for CORS configuration:
```
Pattern: (?i)allow_origins\s*=\s*\[?\s*['\"\*]
Pattern: (?i)cors_allow_all
Pattern: (?i)Access-Control-Allow-Origin.*\*
Pattern: (?i)CORS\(.*origins\s*=\s*\[?\s*['\"\*]
Pattern: (?i)cors:\s*true
```

Severity: **HIGH** for `allow_origins = ["*"]` in production.
Severity: **MEDIUM** for missing CORS configuration entirely (could be permissive by default).

Also check for missing security headers:
- `X-Content-Type-Options: nosniff`
- `X-Frame-Options: DENY`
- `Strict-Transport-Security` (HSTS)
- `Content-Security-Policy`
- `X-XSS-Protection`

### 3I: Missing Rate Limiting

Search for authentication endpoints:

```
Pattern: (?i)@(app|router)\.(post|put)\(.*(/login|/signin|/register|/signup|/forgot.password|/reset.password|/verify|/otp)
Pattern: (?i)@(app|router)\.(post|put)\(.*(/auth/)
```

Then check if rate limiting middleware is applied:
```
Pattern: (?i)(slowapi|ratelimit|rate.limit|throttle|limiter)
```

Severity: **HIGH** for auth endpoints without rate limiting.
Severity: **MEDIUM** for API endpoints without any rate limiting.

### 3J: Missing CSRF Protection

For state-changing endpoints (POST, PUT, DELETE, PATCH):

```
Pattern: (?i)csrf
Pattern: (?i)CSRFMiddleware
Pattern: (?i)csrf_protect
Pattern: (?i)csurf
Pattern: (?i)X-CSRF-Token
Pattern: (?i)X-XSRF-Token
```

If no CSRF protection middleware or token validation is found:
- Severity: **HIGH** if the app uses cookie-based auth (session or JWT in cookies).
- Severity: **MEDIUM** if the app uses header-based token auth only.

---

## Step 4: Authentication and Authorization Audit

Read the authentication-related files and verify these security requirements.

### 4A: Identify Auth Files

Use Glob and Grep to find:
- Auth route handlers (`login`, `register`, `logout`, `refresh`, `forgot-password`)
- Auth middleware / guards
- Token generation and validation logic
- Password hashing utilities
- RBAC / permission checks

### 4B: JWT Storage Audit

**Check:** JWT tokens MUST be stored in HTTP-Only cookies, NEVER in localStorage or sessionStorage.

Search for violations:
```
Pattern: localStorage\.setItem\(.*[Tt]oken
Pattern: sessionStorage\.setItem\(.*[Tt]oken
Pattern: localStorage\.getItem\(.*[Tt]oken
Pattern: sessionStorage\.getItem\(.*[Tt]oken
Pattern: (?i)Authorization.*Bearer.*localStorage
```

Search for correct implementation:
```
Pattern: (?i)httponly\s*[:=]\s*[Tt]rue
Pattern: (?i)set.cookie.*httponly
Pattern: (?i)secure\s*[:=]\s*[Tt]rue
Pattern: (?i)samesite\s*[:=]\s*['\"]?(strict|lax)
```

- JWT in localStorage/sessionStorage = **CRITICAL** (violates Alpha AI standard)
- Missing httponly flag on auth cookies = **CRITICAL**
- Missing secure flag on auth cookies = **HIGH**
- Missing samesite attribute = **MEDIUM**

### 4C: CSRF Double-Submit Cookie Pattern

Verify the CSRF implementation:
- A separate CSRF token cookie (NOT httponly, readable by JS)
- The JS reads this cookie and sends it in a custom header (e.g., `X-CSRF-Token`)
- The server compares the cookie value with the header value
- State-changing requests (POST/PUT/DELETE/PATCH) require CSRF validation

Missing CSRF double-submit pattern = **HIGH**

### 4D: Password Hashing Audit

Search for password hashing implementation:
```
Pattern: (?i)bcrypt
Pattern: (?i)argon2
Pattern: (?i)pbkdf2
Pattern: (?i)scrypt
```

Search for insecure hashing:
```
Pattern: (?i)hashlib\.md5\(
Pattern: (?i)hashlib\.sha1\(
Pattern: (?i)hashlib\.sha256\(.*password
Pattern: (?i)md5\(.*password
Pattern: (?i)sha1\(.*password
```

- Using MD5 or SHA1 for passwords = **CRITICAL**
- Using SHA256 without salt for passwords = **HIGH**
- Using bcrypt/argon2/scrypt = **INFO** (correct)
- No password hashing found = **CRITICAL**

### 4E: Token Expiration Audit

Read token generation code and verify:
- Access token expiration: should be <= 30 minutes
- Refresh token expiration: should be <= 7 days
- Token contains minimal claims (no sensitive data in payload)

```
Pattern: (?i)(access.*expir|expir.*access|ACCESS_TOKEN.*EXPIR|timedelta.*minutes)
Pattern: (?i)(refresh.*expir|expir.*refresh|REFRESH_TOKEN.*EXPIR|timedelta.*days)
```

- Access token > 30 minutes = **HIGH**
- Refresh token > 7 days = **MEDIUM**
- No expiration set = **CRITICAL**

### 4F: Logout Token Blacklist

Verify that logout invalidates tokens:
```
Pattern: (?i)(blacklist|blocklist|revoke|invalidat).*token
Pattern: (?i)redis.*(blacklist|blocklist|set.*token)
```

- No token blacklisting on logout = **HIGH** (tokens remain valid after logout)

### 4G: RBAC on Admin Endpoints

Search for admin routes:
```
Pattern: (?i)@.*(/admin|/dashboard|/users|/settings|/config)
Pattern: (?i)router.*prefix.*admin
```

Then verify each admin route has role/permission checks:
```
Pattern: (?i)(is_admin|is_superuser|role.*admin|permission|authorize|Depends.*admin|require_role|has_permission)
```

- Admin endpoints without RBAC = **CRITICAL**
- Missing role hierarchy enforcement = **HIGH**

---

## Step 5: Docker Security Audit

Only run if Dockerfiles exist in the project.

Use Glob to find all Dockerfiles, then Read each one.

### 5A: Running as Root

Check if Dockerfile creates and uses a non-root user:
```
Pattern: USER\s+(?!root)
Pattern: useradd|adduser|groupadd
```

- No `USER` directive (defaults to root) = **HIGH**
- Explicitly sets `USER root` = **HIGH**
- Uses non-root user = **INFO** (correct)

### 5B: Tag Pinning

```
Pattern: FROM\s+\w+:latest
Pattern: FROM\s+\w+\s*$
```

- Using `:latest` tag = **MEDIUM** (unpredictable builds)
- No tag specified = **MEDIUM**
- Pinned version tag = **INFO** (correct)

### 5C: Secrets in Dockerfile

```
Pattern: (?i)(ENV|ARG)\s+(PASSWORD|SECRET|API_KEY|TOKEN|PRIVATE_KEY|AWS_ACCESS|DATABASE_URL)\s*=
Pattern: (?i)COPY.*\.env
Pattern: (?i)ADD.*\.env
```

- Secrets hardcoded in ENV/ARG = **CRITICAL**
- Copying .env file into image = **HIGH**

### 5D: Unnecessary Packages

Check if the Dockerfile installs debugging/unnecessary tools in production:
```
Pattern: (?i)(apt-get|apk add).*\b(vim|nano|curl|wget|telnet|netcat|nmap|ssh|gdb|strace)\b
```

- Debugging tools in production image = **LOW**
- No multi-stage build (dev tools in final image) = **MEDIUM**

### 5E: Health Check

```
Pattern: HEALTHCHECK
```

- No HEALTHCHECK directive = **LOW** (recommended for orchestration)
- HEALTHCHECK present = **INFO** (correct)

### 5F: Docker Compose Security

If `docker-compose.yml` exists, check:
```
Pattern: privileged:\s*true
Pattern: network_mode:\s*host
Pattern: pid:\s*host
Pattern: cap_add:
```

- `privileged: true` = **CRITICAL**
- `network_mode: host` = **MEDIUM**
- `pid: host` = **HIGH**

---

## Step 6: OWASP Top 10 (2021) Checklist

Go through each OWASP Top 10 category systematically. Use findings from previous steps and add any additional checks.

### A01: Broken Access Control

Checks (many covered in Step 4):
- [ ] Verify principle of least privilege on all endpoints
- [ ] Check that users cannot access other users' data by manipulating IDs (IDOR)
- [ ] Verify directory listing is disabled on static file servers
- [ ] Check that API responses do not expose more data than intended
- [ ] Verify CORS is properly configured (not wildcard in production)
- [ ] Check that JWT cannot be modified to escalate roles

```
Pattern: (?i)\.(id|user_id|account_id)\s*=.*request\.(args|params|query|body|json)
```

IDOR vulnerability (user controls resource ID without ownership check) = **HIGH**

### A02: Cryptographic Failures

- [ ] Verify TLS/HTTPS is enforced (no HTTP in production)
- [ ] Check for weak cryptographic algorithms (DES, RC4, MD5 for integrity)
- [ ] Verify sensitive data is encrypted at rest
- [ ] Check that passwords are salted and hashed (covered in Step 4D)
- [ ] Verify no sensitive data in URLs (tokens in query strings)

```
Pattern: (?i)(DES|RC4|RC2|Blowfish|MD5|SHA1)\b
Pattern: (?i)http:\/\/(?!localhost|127\.0\.0\.1|0\.0\.0\.0)
Pattern: (?i)\?.*token=
Pattern: (?i)\?.*api_key=
Pattern: (?i)\?.*password=
```

Sensitive data in URL query parameters = **HIGH**
Weak crypto algorithms = **HIGH**
HTTP URLs to external services = **MEDIUM**

### A03: Injection

Covered in Step 3A (SQL), Step 3B (Command), Step 3F (Deserialization).

Additional checks:
- [ ] NoSQL injection (MongoDB query injection)
- [ ] LDAP injection
- [ ] Template injection (SSTI)

```
Pattern: (?i)\.find\(\s*\{.*request\.(args|form|json|body)
Pattern: (?i)\.aggregate\(\s*\[.*request\.
Pattern: (?i)(render_template_string|Template\().*request\.
Pattern: (?i)jinja2\.Template\(.*request\.
```

NoSQL injection = **HIGH**
Server-Side Template Injection (SSTI) = **CRITICAL**

### A04: Insecure Design

Review for:
- [ ] Missing input validation on critical business logic
- [ ] Missing transaction limits / business rule enforcement
- [ ] No abuse prevention on sensitive operations
- [ ] Missing multi-step verification for critical actions (delete account, transfer funds)

This is largely a manual review. Flag any endpoints that perform critical operations without confirmation or multi-step verification.

### A05: Security Misconfiguration

```
Pattern: (?i)DEBUG\s*=\s*True
Pattern: (?i)debug\s*[:=]\s*true
Pattern: (?i)FLASK_ENV\s*=\s*development
Pattern: (?i)NODE_ENV\s*=\s*development
Pattern: (?i)AllowedHosts\s*=\s*\[\s*['\*]
Pattern: (?i)app\.debug\s*=\s*True
```

Also check:
- [ ] Default credentials still in use
- [ ] Unnecessary features enabled (admin panels, debug endpoints)
- [ ] Error messages expose stack traces to users
- [ ] Default secret keys (e.g., Django `SECRET_KEY = 'django-insecure-...'`)

```
Pattern: (?i)django-insecure-
Pattern: (?i)changeme
Pattern: (?i)default.*password
Pattern: (?i)password.*123
Pattern: (?i)admin.*admin
```

Debug mode in production config = **HIGH**
Default credentials = **CRITICAL**
Default secret keys = **CRITICAL**

### A06: Vulnerable and Outdated Components

Covered in Step 2 (Dependency Vulnerability Scan).

Additional check:
- [ ] Are there vendored/copied libraries that are outdated?
- [ ] Are there CDN-loaded scripts without integrity hashes (SRI)?

```
Pattern: <script\s+src\s*=\s*['\"]https?:\/\/(?!.*integrity)
Pattern: <link\s+.*href\s*=\s*['\"]https?:\/\/(?!.*integrity)
```

CDN scripts without SRI = **MEDIUM**

### A07: Identification and Authentication Failures

Covered in Step 4 (Auth Audit).

Additional checks:
- [ ] Verify session IDs are rotated after login
- [ ] Check for password complexity requirements
- [ ] Verify account lockout after failed attempts
- [ ] Check multi-factor auth availability for sensitive operations

### A08: Software and Data Integrity Failures

- [ ] Verify CI/CD pipeline integrity (no unsigned deployments)
- [ ] Check for insecure deserialization (covered in Step 3F)
- [ ] Verify update mechanisms use signed packages
- [ ] Check for auto-update without verification

```
Pattern: (?i)pip install.*--trusted-host
Pattern: (?i)npm install.*--ignore-scripts
Pattern: (?i)verify.*ssl.*false
Pattern: (?i)ssl.*verify.*false
Pattern: (?i)PYTHONHTTPSVERIFY\s*=\s*0
```

SSL verification disabled = **HIGH**
Trusted hosts bypassing HTTPS = **HIGH**

### A09: Security Logging and Monitoring Failures

- [ ] Verify authentication events are logged (login success/failure)
- [ ] Verify authorization failures are logged
- [ ] Check for structured logging (not just print statements)
- [ ] Verify sensitive data is NOT logged (passwords, tokens, PII)
- [ ] Check for log injection vulnerabilities

```
Pattern: (?i)(logging|logger)\.(info|warning|error|critical)
Pattern: (?i)print\(.*password
Pattern: (?i)print\(.*token
Pattern: (?i)print\(.*secret
Pattern: (?i)console\.log\(.*password
Pattern: (?i)console\.log\(.*token
```

Logging passwords/tokens = **HIGH**
No structured logging = **MEDIUM**
No auth event logging = **MEDIUM**

### A10: Server-Side Request Forgery (SSRF)

Covered in Step 3E.

Additional checks:
- [ ] Verify URL validation on user-supplied URLs
- [ ] Check for allowlists on outgoing requests
- [ ] Verify internal service URLs are not exposed to users

---

## Step 7: Generate Security Report

After completing all scans, compile findings into a comprehensive report.

Count findings by severity:
- CRITICAL: Findings that require immediate action
- HIGH: Findings that should be fixed before next release
- MEDIUM: Findings that should be addressed in upcoming sprints
- LOW: Improvements to consider
- INFO: Informational / good practices observed

Determine the overall Risk Score:
- Any CRITICAL findings = **CRITICAL** risk
- No CRITICAL but HIGH findings = **HIGH** risk
- No CRITICAL/HIGH but MEDIUM findings = **MEDIUM** risk
- Only LOW/INFO findings = **LOW** risk

Generate the report and save as `SECURITY_AUDIT_REPORT.md` in the project root:

```markdown
# Security Audit Report

**Date**: [today's date]
**Project**: [project name from package.json or pyproject.toml]
**Auditor**: Claude Security Scanner (Cortex)
**Scan Type**: [Standard / Full] [Auto-fix: Yes/No]
**Risk Score**: [CRITICAL / HIGH / MEDIUM / LOW]

---

## Executive Summary

[2-3 sentences describing the overall security posture, major concerns, and confidence level]

---

## Findings Summary

| Category                        | Critical | High | Medium | Low | Info |
|---------------------------------|----------|------|--------|-----|------|
| Secret Detection                |          |      |        |     |      |
| Dependency Vulnerabilities      |          |      |        |     |      |
| SQL Injection                   |          |      |        |     |      |
| Command Injection               |          |      |        |     |      |
| Cross-Site Scripting (XSS)      |          |      |        |     |      |
| Path Traversal                  |          |      |        |     |      |
| SSRF                            |          |      |        |     |      |
| Insecure Deserialization        |          |      |        |     |      |
| Authentication & Authorization  |          |      |        |     |      |
| Docker Security                 |          |      |        |     |      |
| OWASP Top 10                    |          |      |        |     |      |
| **TOTAL**                       | **X**    | **X**| **X**  |**X**|**X** |

---

## Detailed Findings

### CRITICAL Findings

#### [C-001] [Title]
- **Category**: [category]
- **File**: [file path]
- **Line**: [line number]
- **Description**: [detailed explanation of the vulnerability]
- **Impact**: [what an attacker could do]
- **Remediation**: [specific fix with code example]
- **Reference**: [CWE/CVE/OWASP reference]

[Repeat for each CRITICAL finding]

---

### HIGH Findings

#### [H-001] [Title]
- **Category**: [category]
- **File**: [file path]
- **Line**: [line number]
- **Description**: [explanation]
- **Impact**: [impact]
- **Remediation**: [fix]
- **Reference**: [reference]

[Repeat for each HIGH finding]

---

### MEDIUM Findings

#### [M-001] [Title]
[Same format as above]

---

### LOW Findings

#### [L-001] [Title]
[Same format as above]

---

### INFO (Good Practices Observed)

#### [I-001] [Title]
[Description of correct security implementation observed]

---

## OWASP Top 10 Compliance Matrix

| # | Category                              | Status | Findings |
|---|---------------------------------------|--------|----------|
| A01 | Broken Access Control               | [PASS/WARN/FAIL] | [summary] |
| A02 | Cryptographic Failures              | [PASS/WARN/FAIL] | [summary] |
| A03 | Injection                           | [PASS/WARN/FAIL] | [summary] |
| A04 | Insecure Design                     | [PASS/WARN/FAIL] | [summary] |
| A05 | Security Misconfiguration           | [PASS/WARN/FAIL] | [summary] |
| A06 | Vulnerable and Outdated Components  | [PASS/WARN/FAIL] | [summary] |
| A07 | Identification and Authentication   | [PASS/WARN/FAIL] | [summary] |
| A08 | Software and Data Integrity         | [PASS/WARN/FAIL] | [summary] |
| A09 | Security Logging and Monitoring     | [PASS/WARN/FAIL] | [summary] |
| A10 | Server-Side Request Forgery (SSRF)  | [PASS/WARN/FAIL] | [summary] |

---

## Remediation Plan

### Immediate Actions (within 24 hours)
1. [Most critical fix needed]
2. [Second critical fix]
3. [Third critical fix]

### Short-Term (within 1 week)
1. [HIGH severity fixes]
2. ...

### Medium-Term (within 1 month)
1. [MEDIUM severity fixes]
2. ...

### Long-Term (ongoing)
1. [LOW severity improvements]
2. ...

---

## Recommendations

### Security Infrastructure
- [ ] Set up automated dependency scanning in CI/CD pipeline
- [ ] Configure pre-commit hooks for secret detection
- [ ] Enable SAST scanning in pull request checks
- [ ] Set up security monitoring and alerting

### Security Policies
- [ ] Implement mandatory code review for security-sensitive changes
- [ ] Establish secret rotation schedule
- [ ] Document incident response procedures
- [ ] Schedule quarterly security audits
```

---

## Step 8: Auto-Fix (only with --fix flag)

If `--fix` is in $ARGUMENTS, automatically remediate the following safe fixes:

### 8A: Add .gitignore Entries

If `.env` files are not in `.gitignore`, add them:

```
# Security: Environment files
.env
.env.local
.env.production
.env.staging
.env.development
*.pem
*.key
*.p12
*.pfx
```

### 8B: Update Insecure Dependencies

```bash
# Python: Update vulnerable packages
pip install --upgrade [vulnerable-package] 2>/dev/null

# Node.js: Auto-fix vulnerabilities
npm audit fix 2>/dev/null
```

Only run `npm audit fix` (not `npm audit fix --force` which may introduce breaking changes).

### 8C: Add Security Headers Middleware

If missing, offer to add security headers middleware:

**FastAPI:**
```python
from fastapi.middleware.trustedhost import TrustedHostMiddleware
from starlette.middleware.cors import CORSMiddleware

# Add to main app
app.add_middleware(
    CORSMiddleware,
    allow_origins=["https://yourdomain.com"],  # NOT "*"
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE", "PATCH"],
    allow_headers=["*"],
)

@app.middleware("http")
async def add_security_headers(request, call_next):
    response = await call_next(request)
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["X-Frame-Options"] = "DENY"
    response.headers["X-XSS-Protection"] = "1; mode=block"
    response.headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains"
    response.headers["Content-Security-Policy"] = "default-src 'self'"
    response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
    response.headers["Permissions-Policy"] = "camera=(), microphone=(), geolocation=()"
    return response
```

### 8D: Fix yaml.load Without SafeLoader

Replace `yaml.load(` with `yaml.safe_load(` where found.

### 8E: Fix Debug Mode in Production

If `DEBUG = True` is found in non-development config files, change to `DEBUG = False` or `DEBUG = os.getenv("DEBUG", "False").lower() == "true"`.

### 8F: Add Dockerfile Security Improvements

If Dockerfile has no non-root USER, add:
```dockerfile
RUN addgroup --system appgroup && adduser --system --ingroup appgroup appuser
USER appuser
```

If Dockerfile uses `:latest`, suggest pinning to a specific version (but do NOT auto-change as it may break builds).

**Important:** For any auto-fix, create a summary of changes made:
```markdown
## Auto-Fix Summary
| Fix | File | Change | Status |
|-----|------|--------|--------|
| Added .env to .gitignore | .gitignore | Added 6 entries | Applied |
| Fixed npm vulnerabilities | package-lock.json | npm audit fix | Applied |
| ... | ... | ... | ... |
```

---

## Step 9: Output Summary

After generating the report, display a final summary box:

```
+============================================================+
|                   SECURITY SCAN COMPLETE                    |
+============================================================+
| Risk Score: [CRITICAL/HIGH/MEDIUM/LOW]                     |
|                                                            |
| Findings:                                                  |
|   Critical: [N]                                            |
|   High:     [N]                                            |
|   Medium:   [N]                                            |
|   Low:      [N]                                            |
|   Info:     [N]                                            |
|                                                            |
| Top 3 Actions Required:                                    |
|   1. [Most critical action]                                |
|   2. [Second most critical action]                         |
|   3. [Third most critical action]                          |
|                                                            |
| Report saved: SECURITY_AUDIT_REPORT.md                     |
+============================================================+
```

If the scan found CRITICAL issues, add a strong warning:

```
!! WARNING: CRITICAL security vulnerabilities detected.
!! Do NOT deploy until all CRITICAL findings are resolved.
!! See SECURITY_AUDIT_REPORT.md for full details and remediation steps.
```

If the scan found no CRITICAL or HIGH issues:

```
Security posture is acceptable for deployment.
Review MEDIUM/LOW findings for continuous improvement.
```

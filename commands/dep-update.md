---
description: "Auto-update dependencies safely: check outdated packages, review changelogs, test after each bump, rollback on failure. Usage: /dep-update [--security-only] [--major] [--dry-run]"
---

# Automated Dependency Update Manager

$ARGUMENTS = optional flags for scope control (`--security-only`, `--major`, `--dry-run`, or combination).

Parse the arguments:
- `--security-only` — Only apply packages with known CVEs/security advisories. Skip all non-security updates.
- `--major` — Include major version bumps (breaking changes). Without this flag, major bumps are skipped and reported.
- `--dry-run` — Analyze and report what would be updated, but make ZERO changes to any files.
- No arguments — Apply patch and minor updates. Skip major bumps. Report everything.

---

## Step 1: Detect Project Type and Inventory Current Dependencies

### 1a: Identify Package Ecosystem(s)

Scan the project root and subdirectories to determine what package ecosystems are in use.

```bash
echo "=== Detecting Project Type ==="

# Python indicators
echo "--- Python ---"
ls -la requirements*.txt 2>/dev/null
ls -la pyproject.toml 2>/dev/null
ls -la setup.py 2>/dev/null
ls -la setup.cfg 2>/dev/null
ls -la Pipfile 2>/dev/null
ls -la poetry.lock 2>/dev/null
ls -la uv.lock 2>/dev/null

# Node.js indicators
echo "--- Node.js ---"
ls -la package.json 2>/dev/null
ls -la package-lock.json 2>/dev/null
ls -la yarn.lock 2>/dev/null
ls -la pnpm-lock.yaml 2>/dev/null
ls -la bun.lockb 2>/dev/null

# Rust indicators
echo "--- Rust ---"
ls -la Cargo.toml 2>/dev/null

# Go indicators
echo "--- Go ---"
ls -la go.mod 2>/dev/null

# Java/Gradle indicators
echo "--- Java/Gradle ---"
ls -la build.gradle.kts build.gradle pom.xml 2>/dev/null
ls -la gradle/wrapper/gradle-wrapper.properties 2>/dev/null
```

Determine the primary and secondary ecosystems. A project may have BOTH backend and frontend dependencies (e.g., FastAPI/NestJS/Spring Boot backend + Next.js frontend). Handle each ecosystem independently.

**For Java/Gradle projects**, use:
- `./gradlew dependencies` to list all dependencies
- `./gradlew dependencyUpdates` (with com.github.ben-manes.versions plugin) to check for updates
- Update versions in `build.gradle.kts` directly
- Run `./gradlew build test` after each update to verify

### 1b: Record Current Dependency Versions

For **Python** projects, read dependency files and record every pinned version:

```bash
# For requirements.txt
if [ -f requirements.txt ]; then
    echo "=== Production Dependencies (requirements.txt) ==="
    cat requirements.txt
fi

if [ -f requirements-dev.txt ]; then
    echo "=== Dev Dependencies (requirements-dev.txt) ==="
    cat requirements-dev.txt
fi

if [ -f requirements/base.txt ]; then
    echo "=== Split Requirements ==="
    for f in requirements/*.txt; do echo "--- $f ---"; cat "$f"; done
fi

# For pyproject.toml
if [ -f pyproject.toml ]; then
    echo "=== pyproject.toml dependencies ==="
    cat pyproject.toml
fi

# For Pipfile
if [ -f Pipfile ]; then
    echo "=== Pipfile ==="
    cat Pipfile
fi
```

For **Node.js** projects, read package.json and separate production from dev dependencies:

```bash
if [ -f package.json ]; then
    echo "=== package.json ==="
    cat package.json
fi
```

Parse `dependencies` (production) vs `devDependencies` (development) vs `peerDependencies` (peer) from package.json. Record each package name and its current version constraint.

### 1c: Create a Snapshot for Rollback

Before making ANY changes, create backup copies of all dependency files so we can restore them if something goes wrong.

```bash
BACKUP_DIR=".dep-update-backup-$(date +%Y%m%d%H%M%S)"
mkdir -p "$BACKUP_DIR"

# Python backups
cp requirements*.txt "$BACKUP_DIR/" 2>/dev/null
cp pyproject.toml "$BACKUP_DIR/" 2>/dev/null
cp Pipfile "$BACKUP_DIR/" 2>/dev/null
cp Pipfile.lock "$BACKUP_DIR/" 2>/dev/null
cp poetry.lock "$BACKUP_DIR/" 2>/dev/null
cp uv.lock "$BACKUP_DIR/" 2>/dev/null

# Node.js backups
cp package.json "$BACKUP_DIR/" 2>/dev/null
cp package-lock.json "$BACKUP_DIR/" 2>/dev/null
cp yarn.lock "$BACKUP_DIR/" 2>/dev/null
cp pnpm-lock.yaml "$BACKUP_DIR/" 2>/dev/null

echo "Backup created at: $BACKUP_DIR"
ls -la "$BACKUP_DIR/"
```

Record the backup directory path. This is our safety net.

### 1d: Separate Production vs Dev Dependencies

Build two lists:
- **Production dependencies** — packages required at runtime
- **Dev dependencies** — packages only needed for development, testing, linting

For Python:
- `requirements.txt` or `[project].dependencies` in pyproject.toml = production
- `requirements-dev.txt` or `[project.optional-dependencies].dev` in pyproject.toml = dev
- If no separation exists, treat ALL as production (conservative)

For Node.js:
- `dependencies` in package.json = production
- `devDependencies` in package.json = dev
- `peerDependencies` in package.json = peer (report only, do not update)

---

## Step 2: Check for Outdated Packages and Security Vulnerabilities

Use Agent tool (mode = "bypassPermissions") to run these checks in PARALLEL for speed:

### Task 1: Check Outdated Python Packages

```bash
echo "=== Python Outdated Packages ==="

# Method 1: pip list --outdated (always available)
pip list --outdated --format=json 2>/dev/null || pip list --outdated 2>/dev/null

# Method 2: pip-compile (if pip-tools installed)
if command -v pip-compile &>/dev/null; then
    echo "--- pip-compile dry run ---"
    pip-compile --upgrade --dry-run requirements.txt 2>/dev/null
fi

# Method 3: poetry (if poetry project)
if [ -f poetry.lock ]; then
    poetry show --outdated 2>/dev/null
fi

# Method 4: uv (if uv project)
if command -v uv &>/dev/null && [ -f uv.lock ]; then
    uv pip list --outdated 2>/dev/null
fi
```

### Task 2: Check Outdated Node.js Packages

```bash
echo "=== Node.js Outdated Packages ==="

# npm outdated (returns non-zero if outdated packages exist, that is normal)
if [ -f package-lock.json ]; then
    npm outdated --json 2>/dev/null || npm outdated 2>/dev/null
fi

# yarn outdated
if [ -f yarn.lock ]; then
    yarn outdated --json 2>/dev/null || yarn outdated 2>/dev/null
fi

# pnpm outdated
if [ -f pnpm-lock.yaml ]; then
    pnpm outdated --format json 2>/dev/null || pnpm outdated 2>/dev/null
fi
```

### Task 3: Security Audit — Python

```bash
echo "=== Python Security Audit ==="

# pip-audit (preferred — checks PyPI advisory DB)
if command -v pip-audit &>/dev/null; then
    pip-audit --format=json 2>/dev/null || pip-audit 2>/dev/null
else
    echo "pip-audit not installed. Installing temporarily..."
    pip install pip-audit --quiet 2>/dev/null
    pip-audit --format=json 2>/dev/null || pip-audit 2>/dev/null
fi

# safety check (alternative)
if command -v safety &>/dev/null; then
    echo "--- safety check ---"
    safety check --json 2>/dev/null || safety check 2>/dev/null
fi

# Check for known vulnerable versions in requirements
echo "--- Checking for known vulnerable patterns ---"
# Common vulnerable packages to flag
pip list --format=json 2>/dev/null | python3 -c "
import json, sys
try:
    packages = json.load(sys.stdin)
    for p in packages:
        name = p.get('name', '').lower()
        version = p.get('version', '')
        print(f'{name}=={version}')
except:
    pass
" 2>/dev/null
```

### Task 4: Security Audit — Node.js

```bash
echo "=== Node.js Security Audit ==="

# npm audit
if [ -f package-lock.json ]; then
    echo "--- npm audit ---"
    npm audit --json 2>/dev/null || npm audit 2>/dev/null
fi

# yarn audit
if [ -f yarn.lock ]; then
    echo "--- yarn audit ---"
    yarn audit --json 2>/dev/null || yarn audit 2>/dev/null
fi

# pnpm audit
if [ -f pnpm-lock.yaml ]; then
    echo "--- pnpm audit ---"
    pnpm audit --json 2>/dev/null || pnpm audit 2>/dev/null
fi
```

### 2a: Classify Each Update

After collecting all outdated package data and security audit results, classify EVERY outdated package into one of four categories based on semantic versioning:

| Classification | Criteria | Risk Level |
|----------------|----------|------------|
| **SECURITY** | Package has a known CVE or security advisory | CRITICAL — always update |
| **MAJOR** | Major version changed (e.g., 1.x.x to 2.x.x) | HIGH — likely breaking changes |
| **MINOR** | Minor version changed (e.g., 1.2.x to 1.3.x) | MEDIUM — new features, usually backward-compatible |
| **PATCH** | Patch version changed (e.g., 1.2.3 to 1.2.4) | LOW — bug fixes only |

Determine classification by comparing current version to latest version using semver rules:
- If the audit flagged a CVE for this package, mark it as SECURITY regardless of version bump size
- If major version digit changed, mark as MAJOR
- If minor version digit changed (major same), mark as MINOR
- If only patch digit changed, mark as PATCH

Build a structured list:

```
PACKAGE_UPDATES = [
    {
        "name": "package-name",
        "current": "1.2.3",
        "latest": "1.2.5",
        "type": "PATCH",
        "has_cve": false,
        "cve_ids": [],
        "severity": "low",
        "is_dev": false,
        "ecosystem": "python"
    },
    ...
]
```

### 2b: Apply Flag Filters

Based on $ARGUMENTS, filter the update list:

- **`--security-only`**: Keep ONLY packages where `has_cve == true`. Remove all MAJOR, MINOR, PATCH updates that have no CVE.
- **`--major`**: Keep ALL updates including MAJOR bumps. Without this flag, move MAJOR updates to "Skipped" list.
- **No flags**: Keep PATCH + MINOR + SECURITY. Move MAJOR to "Skipped" list.
- **`--dry-run`**: Keep the full filtered list but mark everything as "dry run" — proceed through analysis but skip Step 4 (actual updates).

---

## Step 3: Risk Assessment and Changelog Review

### 3a: Build the Risk Assessment Table

Generate a comprehensive risk table for ALL outdated packages:

```markdown
| # | Package | Current | Latest | Type | CVE? | Breaking? | Ecosystem | Dep Type | Risk |
|---|---------|---------|--------|------|------|-----------|-----------|----------|------|
| 1 | requests | 2.28.0 | 2.31.0 | MINOR | No | No | Python | Prod | LOW |
| 2 | django | 4.2.0 | 5.0.0 | MAJOR | No | Yes | Python | Prod | HIGH |
| 3 | lodash | 4.17.20 | 4.17.21 | PATCH | CVE-2021-23337 | No | Node | Prod | CRITICAL |
| ... | ... | ... | ... | ... | ... | ... | ... | ... | ... |
```

Risk scoring:
- **CRITICAL** — Has CVE, must fix immediately
- **HIGH** — Major version bump, likely breaking
- **MEDIUM** — Minor version bump on a core/production dependency
- **LOW** — Patch update or minor update on a dev dependency

### 3b: Check Changelogs for Breaking Changes

For MAJOR updates and high-risk MINOR updates, use Agent tool (mode = "bypassPermissions") to check changelogs in parallel:

For each high-risk package, attempt to fetch release notes:

```bash
# Check GitHub releases via API (most packages link to GitHub)
# Extract repo from PyPI or npm metadata

# Python: get project URL from PyPI
pip show PACKAGE_NAME 2>/dev/null | grep -i "home-page\|project-url"

# Node.js: get repository from npm
npm view PACKAGE_NAME repository.url 2>/dev/null
```

If a GitHub repository is found:
```bash
# Fetch latest releases
gh api repos/OWNER/REPO/releases --jq '.[0:5] | .[] | "\(.tag_name): \(.name)\n\(.body[0:500])"' 2>/dev/null
```

If no GitHub API access, check for common changelog patterns:
```bash
# Check for CHANGELOG in the installed package
pip show -f PACKAGE_NAME 2>/dev/null | grep -i changelog
```

Look for these breaking change indicators in changelogs:
- "BREAKING CHANGE" or "BREAKING:" labels
- "Removed" sections
- "Deprecated" items now removed
- API signature changes
- Dropped Python/Node version support
- Renamed modules, functions, or classes

Record findings for each package:
```
CHANGELOG_NOTES = {
    "package-name": {
        "has_breaking_changes": true,
        "breaking_details": "Removed deprecated `old_function()`. Use `new_function()` instead.",
        "migration_guide_url": "https://...",
        "dropped_python_versions": ["3.7", "3.8"],
        "notes": "..."
    }
}
```

### 3c: Check Codebase Impact for Breaking Changes

For packages with known breaking changes, scan the codebase for affected code:

```bash
# Example: if a package renamed a function
grep -rn "old_function_name" --include="*.py" --include="*.js" --include="*.ts" .
```

Use Grep tool to search for:
- Imports from the package
- Usage of deprecated APIs (if changelog lists them)
- Configuration patterns that changed

Record the number of affected files and lines for each breaking change. This helps prioritize manual review.

---

## Step 4: Execute Updates (Skip if --dry-run)

If `--dry-run` is set, skip this entire step. Jump to Step 7 to generate the report.

### 4a: Determine Update Order

Updates are applied in this strict order to minimize risk:

1. **PATCH updates** (lowest risk, highest confidence)
2. **SECURITY fixes** (critical priority, regardless of bump size)
3. **MINOR updates** (new features, usually safe)
4. **MAJOR updates** (only if `--major` flag is set)

Within each category, update dev dependencies first (less impact if broken), then production dependencies.

### 4b: Pre-Update Baseline

Before applying any updates, verify the test suite passes with current dependencies:

```bash
echo "=== Running baseline tests with current dependencies ==="

# Python tests
if [ -f pytest.ini ] || [ -f pyproject.toml ] || [ -d tests/ ] || [ -d test/ ]; then
    echo "--- Running pytest ---"
    python -m pytest --tb=short -q 2>&1
    BASELINE_PYTHON=$?
    echo "Python test exit code: $BASELINE_PYTHON"
fi

# Node.js tests
if [ -f package.json ]; then
    echo "--- Running npm test ---"
    npm test 2>&1
    BASELINE_NODE=$?
    echo "Node test exit code: $BASELINE_NODE"
fi

# Linting baseline
echo "=== Running baseline linter ==="
if command -v ruff &>/dev/null; then
    ruff check . 2>&1
elif command -v flake8 &>/dev/null; then
    flake8 . 2>&1
fi

if [ -f package.json ]; then
    npx eslint . 2>&1 || npm run lint 2>&1
fi
```

If the baseline tests FAIL, warn the user: "Tests already fail before updates. Proceeding with updates, but test failures cannot be attributed solely to dependency changes."

Record the baseline test results.

### 4c: Apply Updates One at a Time (Safe Mode)

For EACH package in the update queue, perform this cycle:

#### Python Package Update Cycle:

```bash
PACKAGE="package-name"
OLD_VERSION="1.2.3"
NEW_VERSION="1.2.5"

echo "=== Updating $PACKAGE: $OLD_VERSION -> $NEW_VERSION ==="

# 1. Update the version in requirements file
# (Use Edit tool to modify requirements.txt or pyproject.toml)

# 2. Install the updated package
pip install "$PACKAGE==$NEW_VERSION" 2>&1
INSTALL_EXIT=$?

if [ $INSTALL_EXIT -ne 0 ]; then
    echo "FAILED: Installation of $PACKAGE==$NEW_VERSION failed"
    # Rollback
    pip install "$PACKAGE==$OLD_VERSION" 2>&1
    exit 1
fi

# 3. Run linter
echo "--- Linter check ---"
if command -v ruff &>/dev/null; then
    ruff check . 2>&1
    LINT_EXIT=$?
elif command -v flake8 &>/dev/null; then
    flake8 . 2>&1
    LINT_EXIT=$?
else
    LINT_EXIT=0
fi

# 4. Run test suite
echo "--- Test suite ---"
python -m pytest --tb=short -q 2>&1
TEST_EXIT=$?

# 5. Evaluate result
if [ $TEST_EXIT -eq 0 ]; then
    echo "PASS: $PACKAGE updated successfully to $NEW_VERSION"
else
    echo "FAIL: Tests broke after updating $PACKAGE to $NEW_VERSION"
    echo "Rolling back to $OLD_VERSION..."
    pip install "$PACKAGE==$OLD_VERSION" 2>&1
    # Revert the file change using Edit tool
fi
```

#### Node.js Package Update Cycle:

```bash
PACKAGE="package-name"
OLD_VERSION="1.2.3"
NEW_VERSION="1.2.5"

echo "=== Updating $PACKAGE: $OLD_VERSION -> $NEW_VERSION ==="

# 1. Install the updated version
npm install "$PACKAGE@$NEW_VERSION" 2>&1
INSTALL_EXIT=$?

if [ $INSTALL_EXIT -ne 0 ]; then
    echo "FAILED: Installation of $PACKAGE@$NEW_VERSION failed"
    npm install "$PACKAGE@$OLD_VERSION" 2>&1
    exit 1
fi

# 2. Run linter
echo "--- Linter check ---"
npm run lint 2>&1 || npx eslint . 2>&1
LINT_EXIT=$?

# 3. Run test suite
echo "--- Test suite ---"
npm test 2>&1
TEST_EXIT=$?

# 4. Run type checking (if TypeScript)
if [ -f tsconfig.json ]; then
    echo "--- TypeScript check ---"
    npx tsc --noEmit 2>&1
    TSC_EXIT=$?
else
    TSC_EXIT=0
fi

# 5. Evaluate result
COMBINED_EXIT=$(( TEST_EXIT + TSC_EXIT ))
if [ $COMBINED_EXIT -eq 0 ]; then
    echo "PASS: $PACKAGE updated successfully to $NEW_VERSION"
else
    echo "FAIL: Tests/types broke after updating $PACKAGE to $NEW_VERSION"
    echo "Rolling back to $OLD_VERSION..."
    npm install "$PACKAGE@$OLD_VERSION" 2>&1
fi
```

### 4d: Track Results

Maintain three lists throughout the update process:

```
UPDATED_PACKAGES = []      # Successfully updated
FAILED_PACKAGES = []       # Rolled back due to test failure
SKIPPED_PACKAGES = []      # Skipped by policy (major without --major flag, etc.)
SECURITY_FIXES = []        # Security advisories resolved
```

For each package, record:
- Package name
- Old version
- New version (or attempted version)
- Update type (PATCH/MINOR/MAJOR/SECURITY)
- Result (PASS/FAIL/SKIPPED)
- Failure reason (if applicable)
- Test output snippet (if failed)

---

## Step 5: Handle Major Version Updates

This step only executes if `--major` flag is provided. Otherwise, major updates are added to the SKIPPED list with reason "Major version bump — use --major flag to include".

### 5a: Pre-Major-Update Analysis

For each major version bump, BEFORE attempting the update:

1. **Read the migration guide** (if found in Step 3b):

```bash
# If we found a migration guide URL, fetch it
# Use WebFetch to read the migration guide content
```

2. **Scan for deprecated API usage** in the codebase:

Use Grep tool to search for patterns that the changelog identified as removed or renamed:

```bash
# Example: if package v2 removed `old_module`
grep -rn "from package_name.old_module import" --include="*.py" .
grep -rn "import package_name.old_module" --include="*.py" .
grep -rn "require('package-name/old-module')" --include="*.js" --include="*.ts" .
```

3. **Check Python/Node version compatibility**:

```bash
# Verify our runtime matches the new version's requirements
python3 --version
node --version 2>/dev/null
```

If the major update drops support for our current runtime version, SKIP the update and flag it: "Requires Python 3.11+ but project uses Python 3.9".

### 5b: Attempt Major Update with Extended Testing

For each major version bump that passes pre-analysis:

```bash
PACKAGE="big-package"
OLD_VERSION="3.4.2"
NEW_VERSION="4.0.0"

echo "=== MAJOR UPDATE: $PACKAGE $OLD_VERSION -> $NEW_VERSION ==="
echo "WARNING: This is a major version bump. Breaking changes are expected."

# Install new version
pip install "$PACKAGE==$NEW_VERSION" 2>&1 || npm install "$PACKAGE@$NEW_VERSION" 2>&1

# Run extended test suite
echo "--- Full test suite ---"
python -m pytest --tb=long -v 2>&1 || npm test 2>&1

# Run type checking
echo "--- Type checking ---"
mypy . 2>&1 || npx tsc --noEmit 2>&1

# Run the full linter
echo "--- Full linter ---"
ruff check . 2>&1 || npm run lint 2>&1
```

### 5c: Auto-Fix Simple Migrations

If tests fail after a major update and the migration guide documents simple renames or import path changes, attempt auto-fix:

Common auto-fixable patterns:
- **Import path changes**: `from pkg.old_path import X` -> `from pkg.new_path import X`
- **Function renames**: `pkg.old_name()` -> `pkg.new_name()`
- **Parameter renames**: `func(old_param=X)` -> `func(new_param=X)`
- **Constant renames**: `pkg.OLD_CONST` -> `pkg.NEW_CONST`

Use the Edit tool to apply these renames across the codebase. Then re-run the test suite.

If auto-fix resolves the failures, mark the package as UPDATED with a note: "Auto-migrated: [description of changes]".

If auto-fix does NOT resolve all failures, rollback the update AND the auto-fix changes. Add to SKIPPED list with reason: "Major update requires manual migration — [N] test failures remain".

### 5d: Flag Complex Migrations

For major updates that cannot be auto-fixed, generate a detailed migration report:

```markdown
### Manual Migration Required: package-name 3.x -> 4.x

**Breaking Changes Detected:**
1. `old_function()` removed — used in 5 files
2. `Config` class constructor changed — used in 3 files
3. Dropped Python 3.8 support (not applicable to this project)

**Files Affected:**
- `src/module/file1.py` (lines 23, 45, 78)
- `src/module/file2.py` (lines 12, 34)
- `tests/test_module.py` (lines 56, 89, 112)

**Migration Guide:** https://...
**Estimated Effort:** ~2 hours manual work

**Recommendation:** Schedule as a separate task. Do not combine with other dependency updates.
```

---

## Step 6: Update Lock Files and Finalize

### 6a: Regenerate Lock Files

After all successful updates are applied, regenerate the lock files to ensure consistency:

**Python:**

```bash
# If using pip-tools (pip-compile)
if command -v pip-compile &>/dev/null; then
    echo "--- Regenerating requirements via pip-compile ---"
    pip-compile requirements.in -o requirements.txt 2>&1
    if [ -f requirements-dev.in ]; then
        pip-compile requirements-dev.in -o requirements-dev.txt 2>&1
    fi
fi

# If using poetry
if [ -f pyproject.toml ] && command -v poetry &>/dev/null; then
    echo "--- Regenerating poetry.lock ---"
    poetry lock --no-update 2>&1
fi

# If using uv
if command -v uv &>/dev/null && [ -f uv.lock ]; then
    echo "--- Regenerating uv.lock ---"
    uv lock 2>&1
fi

# If using plain pip with requirements.txt, freeze current state
if [ -f requirements.txt ] && ! command -v pip-compile &>/dev/null; then
    echo "--- Freezing current pip state ---"
    pip freeze > requirements.txt.new 2>&1
    echo "Review requirements.txt.new and replace requirements.txt if correct"
fi
```

**Node.js:**

```bash
# npm
if [ -f package-lock.json ]; then
    echo "--- Regenerating package-lock.json ---"
    npm install --package-lock-only 2>&1
fi

# yarn
if [ -f yarn.lock ]; then
    echo "--- Regenerating yarn.lock ---"
    yarn install --frozen-lockfile 2>&1 || yarn install 2>&1
fi

# pnpm
if [ -f pnpm-lock.yaml ]; then
    echo "--- Regenerating pnpm-lock.yaml ---"
    pnpm install --lockfile-only 2>&1
fi
```

### 6b: Final Verification

Run the complete test suite one final time with ALL updates applied:

```bash
echo "=== FINAL VERIFICATION ==="
echo "Running complete test suite with all updates applied..."

# Python
if [ -d tests/ ] || [ -d test/ ]; then
    python -m pytest --tb=short -q 2>&1
    FINAL_PYTHON=$?
    echo "Final Python test exit code: $FINAL_PYTHON"
fi

# Node.js
if [ -f package.json ]; then
    npm test 2>&1
    FINAL_NODE=$?
    echo "Final Node test exit code: $FINAL_NODE"
fi

# Final lint
echo "--- Final lint ---"
ruff check . 2>&1 || flake8 . 2>&1
npm run lint 2>&1

echo "=== FINAL VERIFICATION COMPLETE ==="
```

If the final verification fails but individual updates passed, there may be an interaction between updated packages. In that case:
1. Identify which combination of updates causes the failure
2. Rollback the most recently applied updates one at a time until tests pass
3. Move rolled-back packages to FAILED list with reason: "Cross-dependency conflict with [other-package]"

### 6c: Clean Up Backup

If all updates succeeded and final verification passed:

```bash
echo "All updates verified. Backup retained at: $BACKUP_DIR"
echo "To remove backup: rm -rf $BACKUP_DIR"
echo "To rollback ALL changes: cp $BACKUP_DIR/* . && pip install -r requirements.txt"
```

Do NOT automatically delete the backup. The user may want to rollback later.

---

## Step 7: Generate the Dependency Update Report

Create a comprehensive report file at `DEP_UPDATE_REPORT.md` in the project root.

Use the Write tool to create this file with the following structure:

```markdown
# Dependency Update Report

**Date**: [current date and time]
**Project**: [project name from package.json name or pyproject.toml name or directory name]
**Mode**: [Normal / Security-Only / Major Included / Dry Run]
**Ecosystems**: [Python, Node.js, or both]

---

## Summary

| Status | Count |
|--------|-------|
| Updated successfully | [n] |
| Skipped (major — needs --major flag) | [n] |
| Skipped (manual migration required) | [n] |
| Failed (tests broke, rolled back) | [n] |
| Security fixes applied | [n] |
| Security issues remaining | [n] |
| Total outdated packages found | [n] |

---

## Updates Applied

| # | Package | From | To | Type | Ecosystem | Dep Type | Notes |
|---|---------|------|----|------|-----------|----------|-------|
| 1 | requests | 2.28.0 | 2.31.0 | PATCH | Python | Prod | Clean update |
| 2 | lodash | 4.17.20 | 4.17.21 | SECURITY | Node | Prod | Fixes CVE-2021-23337 |
| 3 | pytest | 7.2.0 | 7.4.0 | MINOR | Python | Dev | New features added |
| ... | ... | ... | ... | ... | ... | ... | ... |

---

## Security Advisories Resolved

| # | CVE ID | Package | Severity | Old Version | Fixed Version | Description |
|---|--------|---------|----------|-------------|---------------|-------------|
| 1 | CVE-2021-23337 | lodash | HIGH | 4.17.20 | 4.17.21 | Prototype pollution |
| ... | ... | ... | ... | ... | ... | ... |

If no security advisories were found:
> No known security vulnerabilities found in current dependencies.

---

## Security Advisories Remaining (Unresolved)

| # | CVE ID | Package | Severity | Current | Fix Available? | Reason Not Fixed |
|---|--------|---------|----------|---------|----------------|------------------|
| 1 | CVE-XXXX-YYYY | pkg | CRITICAL | 1.0.0 | 2.0.0 (major) | Major bump — use --major |
| ... | ... | ... | ... | ... | ... | ... |

If all security issues are resolved:
> All known security vulnerabilities have been resolved.

---

## Failed Updates (Rolled Back)

| # | Package | From | Attempted | Type | Failure Reason |
|---|---------|------|-----------|------|----------------|
| 1 | sqlalchemy | 1.4.0 | 2.0.0 | MAJOR | 12 test failures — async session API changed |
| 2 | webpack | 4.46.0 | 5.88.0 | MAJOR | Build configuration incompatible |
| ... | ... | ... | ... | ... | ... |

If no failures:
> All attempted updates succeeded.

---

## Skipped (Manual Review Needed)

| # | Package | From | Latest | Type | Reason | Estimated Effort |
|---|---------|------|--------|------|--------|------------------|
| 1 | django | 4.2.0 | 5.0.0 | MAJOR | Major bump — requires --major flag | ~4 hours |
| 2 | react | 17.0.2 | 18.2.0 | MAJOR | Breaking: Concurrent rendering changes | ~8 hours |
| ... | ... | ... | ... | ... | ... | ... |

**Detailed Migration Notes:**

### django 4.2.0 -> 5.0.0
- **Breaking changes**: [list from changelog]
- **Files affected**: [count]
- **Migration guide**: [URL]

### react 17.0.2 -> 18.2.0
- **Breaking changes**: [list from changelog]
- **Files affected**: [count]
- **Migration guide**: [URL]

If nothing was skipped:
> All eligible updates were applied.

---

## Environment Info

| Item | Value |
|------|-------|
| Python version | [version] |
| Node.js version | [version] |
| npm/yarn/pnpm version | [version] |
| pip version | [version] |
| OS | [platform] |
| Date | [date] |
| Backup location | [path] |

---

## Rollback Instructions

To undo ALL changes from this update:

### Quick Rollback (from backup):
\`\`\`bash
cp [BACKUP_DIR]/* .
pip install -r requirements.txt    # Python
npm install                         # Node.js
\`\`\`

### Selective Rollback (single package):
\`\`\`bash
# Python
pip install PACKAGE==OLD_VERSION

# Node.js
npm install PACKAGE@OLD_VERSION
\`\`\`

### Git Rollback (if committed):
\`\`\`bash
git diff HEAD~1 --name-only        # See what changed
git checkout HEAD~1 -- FILE         # Revert specific file
\`\`\`
```

Fill in ALL placeholder values with actual data collected during the process. Do not leave any `[placeholder]` unfilled.

---

## Step 8: Output Summary to Console

After writing the report file, display a concise summary box directly in the console output:

```
+============================================================+
|              DEPENDENCY UPDATE COMPLETE                     |
+============================================================+
|                                                            |
|  Mode:          [Normal / Dry Run / Security Only]         |
|  Ecosystems:    [Python / Node.js / Both]                  |
|  Date:          [date]                                     |
|                                                            |
+------------------------------------------------------------+
|  RESULTS                                                   |
+------------------------------------------------------------+
|  Updated:           [n] packages                           |
|  Security Fixes:    [n] CVEs resolved                      |
|  Failed:            [n] rolled back                        |
|  Skipped:           [n] need manual review                 |
+------------------------------------------------------------+
|  BREAKDOWN                                                 |
+------------------------------------------------------------+
|  Patch updates:     [n] applied                            |
|  Minor updates:     [n] applied                            |
|  Major updates:     [n] applied / [n] skipped              |
|  Security patches:  [n] applied / [n] remaining            |
+------------------------------------------------------------+
|                                                            |
|  Report: DEP_UPDATE_REPORT.md                              |
|  Backup: [backup_dir_path]                                 |
|                                                            |
+============================================================+
```

### Dry Run Output

If `--dry-run` was specified, change the header and add a notice:

```
+============================================================+
|          DEPENDENCY UPDATE — DRY RUN (No Changes)          |
+============================================================+
|                                                            |
|  This is a preview. No files were modified.                |
|  Run without --dry-run to apply these updates.             |
|                                                            |
+------------------------------------------------------------+
|  WOULD UPDATE                                              |
+------------------------------------------------------------+
|  Patch updates:     [n] packages                           |
|  Minor updates:     [n] packages                           |
|  Security fixes:    [n] CVEs                               |
|  Major updates:     [n] packages (needs --major flag)      |
+------------------------------------------------------------+
|                                                            |
|  Highest Risk:      [package] [old] -> [new] (MAJOR)      |
|  Most Critical:     [CVE-ID] in [package] ([severity])     |
|                                                            |
|  Report: DEP_UPDATE_REPORT.md                              |
|                                                            |
+============================================================+
```

### Security-Only Output

If `--security-only` was specified:

```
+============================================================+
|          SECURITY-ONLY DEPENDENCY UPDATE                   |
+============================================================+
|                                                            |
|  Only packages with known CVEs were updated.               |
|                                                            |
+------------------------------------------------------------+
|  SECURITY RESULTS                                          |
+------------------------------------------------------------+
|  CVEs resolved:     [n]                                    |
|  CVEs remaining:    [n] (require major bumps)              |
|  Packages updated:  [n]                                    |
|  Packages skipped:  [n] (non-security)                     |
+------------------------------------------------------------+
|                                                            |
|  Report: DEP_UPDATE_REPORT.md                              |
|  Backup: [backup_dir_path]                                 |
|                                                            |
+============================================================+
```

---

## Error Handling and Edge Cases

### No Outdated Packages Found
If all dependencies are already up to date:
```
All dependencies are up to date. No updates needed.
```
Do not create a report file. Simply inform the user.

### No Test Suite Found
If no test suite is detected (no pytest, no npm test script):
- WARN the user: "No test suite detected. Updates will be applied without test verification. This increases risk."
- Ask for confirmation before proceeding (unless --dry-run)
- Still run linting if available

### Network Errors
If PyPI or npm registry is unreachable:
- Report the error clearly
- Suggest checking network connectivity
- Do not attempt updates without being able to verify available versions

### Virtual Environment Not Active (Python)
If no virtual environment is detected:
```bash
# Check for active venv
echo $VIRTUAL_ENV
python -c "import sys; print(sys.prefix)"
```
- WARN: "No virtual environment detected. Installing packages globally is risky."
- Suggest activating a venv first
- Proceed only if user confirms

### Lock File Conflicts
If lock file regeneration fails:
- Keep the updated dependency files (requirements.txt, package.json)
- Report the lock file failure
- Suggest manual resolution: `npm install` or `pip-compile`

### Circular Dependency Issues
If an update introduces a circular dependency:
- Detect from install error output
- Rollback the problematic package
- Report the circular dependency chain

---

## Important Safety Rules

1. **NEVER force-update** without testing. Every single update gets its own test cycle.
2. **NEVER delete the backup** automatically. The user decides when to clean up.
3. **NEVER update peer dependencies** for Node.js — report them but do not modify.
4. **ALWAYS rollback on failure** — leave the project in a working state.
5. **ALWAYS preserve version pinning style** — if requirements.txt uses `==`, keep `==`. If package.json uses `^`, keep `^`.
6. **NEVER modify `.env` or configuration files** — only dependency manifests and lock files.
7. **NEVER skip the baseline test** — we need to know if tests were already broken.
8. **ALWAYS show the diff** of what changed in dependency files before finalizing.
9. **NEVER run `npm audit fix --force`** — this is destructive and unpredictable.
10. **ALWAYS respect the --dry-run flag** — zero file modifications when dry-running.

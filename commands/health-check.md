---
description: "Run a comprehensive project health audit — dependencies, security, code quality, documentation, and CI/CD status."
---

# Project Health Audit

Run a full health check on this project.

## Audit Categories

Use Agent tool (mode = "bypassPermissions") to run these audits in parallel:

### 1. Dependency Health
```bash
# Check for outdated packages
npm outdated 2>&1 || pip list --outdated 2>&1 || go list -u -m all 2>&1

# Check for vulnerabilities
npm audit 2>&1 || safety check 2>&1 || pip audit 2>&1

# Check for unused dependencies
npx depcheck 2>&1 || true
```

### 2. Code Quality Metrics
- Count total lines of code by language
- Identify largest files (potential refactoring targets)
- Find duplicated code patterns
- Check for TODO/FIXME/HACK comments
- Identify dead code or unused exports

### 3. Test Health
```bash
# Run tests with coverage
npm test -- --coverage 2>&1 || pytest --cov --cov-report=term-missing 2>&1
```
- Overall coverage percentage
- Files with 0% coverage
- Test-to-code ratio

### 4. Documentation Coverage
- README.md exists and is comprehensive?
- CONTRIBUTING.md exists?
- API documentation exists?
- Inline code documentation quality
- CHANGELOG maintained?

### 5. CI/CD Status
- CI pipeline configured?
- All pipeline stages present (lint, test, build, deploy)?
- Branch protection rules?
- Automated deployment?

### 6. Security Posture
- Secrets in code? (scan for API keys, passwords)
- .env files in .gitignore?
- HTTPS enforced?
- Dependency vulnerabilities
- OWASP Top 10 basic checks

### 7. Git Health
```bash
echo "=== Branch Count ==="
git branch -a | wc -l
echo "=== Stale Branches (>30 days) ==="
git for-each-ref --sort=-committerdate --format='%(committerdate:short) %(refname:short)' refs/heads/ | tail -10
echo "=== Commit Frequency (last 30 days) ==="
git log --oneline --since="30 days ago" | wc -l
echo "=== Large Files ==="
git rev-list --objects --all | git cat-file --batch-check='%(objecttype) %(objectname) %(objectsize) %(rest)' | awk '/^blob/ {print $3, $4}' | sort -rn | head -10
```

## Health Report

Generate **PROJECT_HEALTH.md**:

```markdown
# Project Health Report
**Generated**: [date]
**Overall Score**: [A/B/C/D/F]

## Summary Dashboard
| Category        | Score | Status |
|----------------|-------|--------|
| Dependencies   | 8/10  | 🟢     |
| Code Quality   | 7/10  | 🟡     |
| Test Coverage  | 6/10  | 🟡     |
| Documentation  | 5/10  | 🔴     |
| CI/CD          | 9/10  | 🟢     |
| Security       | 7/10  | 🟡     |
| Git Health     | 8/10  | 🟢     |

## Priority Actions (Top 5)
1. [Most critical action item]
2. [Second priority]
3. ...

## Detailed Findings
[Per-category detailed results]
```

---

## Remediation Commands

After generating the health report, **actively suggest fix commands** for each issue found. Do NOT just report problems — provide actionable solutions.

### Auto-Fix Actions (Execute automatically for safe fixes):

| Issue Found | Auto-Fix Command |
|-------------|-----------------|
| Outdated dependencies | Suggest: `/dep-update` |
| Vulnerabilities found | Suggest: `/security-scan --fix` |
| Low test coverage | Suggest: `/gen-tests [uncovered-files]` |
| Missing documentation | Suggest: `/gen-docs` |
| Code quality issues | Suggest: `/refactor [problem-files]` |
| Tech debt detected | Suggest: `/tech-debt --action-plan` |
| CI/CD not configured | Suggest: `/gen-ci github-actions` |
| Accessibility issues | Suggest: `/accessibility --fix` |
| Performance bottlenecks | Suggest: `/perf-test [slow-endpoints]` |
| Stale branches | `git branch -d [branch]` (after confirmation) |

### Remediation Priority Matrix

Based on the health report scores, generate a prioritized action plan:

```
╔══════════════════════════════════════════════════════════════╗
║  REMEDIATION PLAN (Priority Order)                           ║
╠══════════════════════════════════════════════════════════════╣
║                                                               ║
║  🔴 CRITICAL (Fix immediately):                              ║
║  1. [Issue] → Run: /[command]                                ║
║  2. [Issue] → Run: /[command]                                ║
║                                                               ║
║  🟡 HIGH (Fix this sprint):                                  ║
║  3. [Issue] → Run: /[command]                                ║
║  4. [Issue] → Run: /[command]                                ║
║                                                               ║
║  🔵 MEDIUM (Schedule for next sprint):                       ║
║  5. [Issue] → Run: /[command]                                ║
║                                                               ║
║  ⚪ LOW (Nice to have):                                      ║
║  6. [Issue] → Run: /[command]                                ║
║                                                               ║
╚══════════════════════════════════════════════════════════════╝
```

### Automated Fix Workflow

If the user approves, chain remediation commands:

```
1. Ask: "Would you like to auto-fix the [N] critical and high priority issues?"
2. If yes, execute commands in priority order:
   a. Run each suggested command
   b. Verify the fix resolved the issue
   c. Mark as fixed in the remediation plan
   d. If a fix fails, report and move to the next one
3. Re-run the health check to verify improvements:
   "Health Score improved: [old] → [new] ([delta] improvement)"
```

---

## Sprint Plan Integration

After health check completes:

```
1. If SPRINT_PLAN.md exists:
   a. Check if health-related tasks exist in the current sprint
   b. Map remediation items to sprint tasks where possible
   c. Create new sprint tasks for critical remediation items not yet tracked:
      "Created sprint task [N.M]: Fix [issue] (Priority: Critical, 2 pts)"
   d. Update sprint plan with health check results
2. If not found: skip silently
```

---

## Continuous Health Monitoring

Suggest ongoing monitoring setup based on findings:

```
If CI/CD is configured:
  → "Add health check as a CI step: /gen-ci --add-health-check"

If monitoring is not configured:
  → "Set up monitoring: /monitoring"

If error tracking is missing:
  → "Add Sentry for error tracking (included in /auto-build Phase 12)"
```

---

## Scheduled Execution (Recommended)

`/health-check` is a natural fit for daily scheduling — it's fast, non-mutating, and the value comes from catching drift early (e.g., a config that worked yesterday but no longer matches the current standards).

### Recommended cadence

| Cadence | When | Rationale |
|---------|------|-----------|
| **Daily** (DEFAULT) | 06:00 local | Runs before the workday starts; results are waiting when the team logs in |
| **Per-commit** | Pre-push hook | Catches health regressions before they hit `main` |
| **Pre-deploy** | CI/CD pipeline step | Blocks deploys that would degrade health score below threshold |

### How to schedule

**Option A: Claude Code `/schedule` (recommended)**

Type `/schedule` in any Claude Code session. Example: `"every day at 06:00 UTC"` for the daily check.

**Option B: OS-level cron (when Claude Code isn't running)**

```
# example — adapt the claude invocation to your CC version
0 6 * * * cd /path/to/repo && <claude one-shot> "/health-check" \
  >> .cortex/scheduled-health-check.log 2>&1
```

**Option C: Git pre-push hook (catches regressions before push)**

Add to `.git/hooks/pre-push` (or via `husky` / `lefthook`):

```bash
#!/bin/bash
# Block push if health score drops below 70/100
<claude one-shot> "/health-check --json" | jq -e '.score >= 70' \
  || { echo "BLOCKED: health check score below 70"; exit 1; }
```

### Mandatory when scheduled

- **ALWAYS** trend the score over time (write each run's score to `.cortex/health-history.json`) — a single point-in-time number is noise; the slope is signal.
- **ALWAYS** alert the team when the score drops by >5 points in a single run, even if still above threshold.
- **NEVER** auto-fix on schedule. Health checks report; humans decide which fixes to take.

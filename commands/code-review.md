---
description: "Run a comprehensive automated code review on staged changes or a specific branch/PR. Usage: /code-review [branch-name] or /code-review --staged"
---

# Automated Code Review

You are a senior code reviewer performing a thorough review. Analyze: **$ARGUMENTS**

## Step 1: Identify Changes

```bash
# If --staged or no args, review staged changes
git diff --cached --name-only 2>/dev/null || git diff --name-only HEAD~1

# If branch name provided, compare against main
git diff main...$ARGUMENTS --name-only 2>/dev/null
```

Read every changed file completely.

## Step 2: Multi-Dimensional Review

Use Agent tool (mode = "bypassPermissions") to run 5 parallel review agents:

### Agent 1: Code Quality
- Clean code principles (SRP, DRY, KISS)
- Function/method length and complexity
- Naming conventions consistency
- Magic numbers and hardcoded values
- Dead code or unused imports
- Proper error handling
- Resource cleanup (connections, file handles)

### Agent 2: Security Analysis
- SQL injection vectors
- XSS vulnerabilities
- Authentication/authorization gaps
- Sensitive data exposure (API keys, passwords)
- Input validation completeness
- CORS configuration
- Dependency vulnerabilities (check package versions)

### Agent 3: Performance Review
- N+1 query patterns
- Missing database indexes (if schema changes)
- Unnecessary re-renders (React)
- Memory leaks (event listeners, subscriptions)
- Unbounded data fetching
- Missing pagination
- Caching opportunities

### Agent 4: Testing Assessment
- Test coverage for new code
- Edge case coverage
- Mock appropriateness
- Test isolation
- Missing negative test cases
- Integration test gaps

### Agent 5: Architecture & Standards
- Consistent with existing patterns
- CLAUDE.md / STANDARDS.md compliance
- API contract changes (breaking changes?)
- Proper abstraction layers
- Dependency direction (no circular deps)
- Documentation updates needed

### Agent Teams Review Mode (When Enabled)

When `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` is set, upgrade to **Agent Teams review mode** where the 5 reviewers become real teammates who debate and challenge each other's findings.

**Team Creation:**

Create an agent team named `code-review-[branch]` with 5 teammates:

| Teammate ID | Role | Focus Area |
|-------------|------|------------|
| quality-reviewer | Code Quality | Clean code (SRP, DRY, KISS), naming, dead code, error handling |
| security-reviewer | Security Analysis | Auth gaps, injection, secrets, OWASP Top 10, CORS |
| perf-reviewer | Performance Review | N+1 queries, caching, memory leaks, pagination, re-renders |
| test-reviewer | Testing Assessment | Coverage, edge cases, mocking quality, integration gaps |
| arch-reviewer | Architecture & Standards | Pattern compliance, layer rules, API contracts, dependencies |

**Adversarial Review Protocol:**

1. All 5 reviewers analyze the changes independently (true parallel — separate Claude sessions)
2. Each posts findings to the shared task list with severity: BLOCKER / WARNING / INFO
3. Reviewers **challenge each other's findings:**
   - Security reviewer: "Quality reviewer missed SQL injection risk on line 42"
   - Perf reviewer: "The N+1 query in user_service.py is higher severity than the naming issue"
   - Arch reviewer: "Service layer is directly accessing the database — layer violation"
4. Cross-domain insights emerge (security reviewer spots performance issues, perf reviewer spots auth bypass)
5. Team lead synthesizes findings into a consensus report ranked by severity
6. Severity override hierarchy: Security > Performance > Architecture > Quality > Style

**Benefits over subagent mode:**
- Reviewers see each other's findings and catch what others missed
- Higher quality reviews through adversarial debate and cross-checking
- Final report is consensus-driven, not just aggregated from independent reviews
- Real-time collaboration catches compound issues (e.g., a pattern that is both insecure AND slow)

**Fallback:** If Agent Teams is not enabled, use the 5 parallel subagents above (standard mode).

## Step 3: Generate Review Report

Format the review as:

```markdown
# Code Review Report
**Date**: [today]
**Scope**: [files reviewed]
**Risk Level**: 🟢 Low / 🟡 Medium / 🔴 High

## Critical Issues (Must Fix)
- [ ] Issue description — file:line — Why it matters

## Suggestions (Should Fix)
- [ ] Suggestion — file:line — Benefit

## Nitpicks (Nice to Have)
- [ ] Nitpick — file:line

## Positive Highlights
- 👍 Good patterns observed

## Summary
[2-3 sentence overall assessment]
```

Save the report as `REVIEW_REPORT.md` in the project root.

---
description: "Complete ship workflow: code-review → lint → test → commit → push → create PR → verify CI. Auto-updates sprint plan. Usage: /ship [commit-message] [--skip-review]"
---

# Ship: Complete PR Workflow

Ship this code with message: **$ARGUMENTS**

---

## Step 0: Automated Code Review (MANDATORY unless --skip-review)

Before shipping, run an automated code review on all staged/changed files:

```
1. Get list of changed files:
   git diff --cached --name-only (staged)
   git diff --name-only (unstaged)

2. For each changed file, analyze:
   - Security issues (hardcoded secrets, SQL injection, XSS, auth bypasses)
   - Performance issues (N+1 queries, missing indexes, sync I/O in async)
   - Code quality (long functions, deep nesting, code duplication)
   - Alpha AI compliance (layer violations, localStorage usage, wrong DB)
   - Test coverage (new code without tests)

3. Classify findings:
   - 🔴 BLOCKER — Must fix before shipping (security vulnerabilities, data loss risks)
   - 🟡 WARNING — Should fix but can ship (code smells, missing tests)
   - ℹ️ INFO — Nice to fix (style, minor improvements)

4. If BLOCKERS found:
   - List all blockers with file:line references
   - Ask user: "Fix blockers before shipping? (Y/n)"
   - If yes, attempt auto-fix for simple issues
   - If no, user explicitly accepts the risk

5. If only WARNINGS:
   - List warnings briefly
   - Proceed to shipping (don't block)
```

If `--skip-review` is in $ARGUMENTS, skip this step entirely.

---

## Step 1: Pre-Ship Checks

```bash
echo "=== Running Linter ==="
ruff check app/ --fix 2>/dev/null || npm run lint --fix 2>&1 || true

echo "=== Running Type Check ==="
mypy app/ --ignore-missing-imports 2>/dev/null || npx tsc --noEmit 2>&1 || true

echo "=== Running Tests ==="
pytest tests/ -x -q 2>/dev/null || npm test 2>&1 || true

echo "=== Build Check ==="
python -c "from app.main import app; print('✅ App loads')" 2>/dev/null || npm run build 2>&1 || true
```

If lint or tests fail, report the issues and ask whether to proceed.

---

## Step 2: Smart Commit

Analyze the changes and generate a conventional commit message if none provided:

```bash
git diff --cached --stat
git diff --cached
```

Format: `<type>(<scope>): <description>`
Types: feat, fix, docs, style, refactor, perf, test, chore, ci

If $ARGUMENTS provided, use it as the commit message.
If not provided, auto-generate from the diff analysis.

---

## Step 3: Push & Create PR

```bash
git add -A
git commit -m "[commit message]"
git push origin $(git branch --show-current)
```

Generate a comprehensive PR description:

```markdown
## What Changed
[Summary of changes based on diff analysis]

## Why
[Inferred motivation from commit message and code changes]

## How to Test
1. [Step-by-step testing instructions]
2. [Expected results]

## Code Review Summary
[Results from Step 0 automated review — blockers fixed, warnings noted]

## Checklist
- [ ] Tests pass locally
- [ ] Code follows project style guidelines
- [ ] Documentation updated (if applicable)
- [ ] No breaking changes (or migration guide provided)
- [ ] Security review passed (Step 0)

## Screenshots
[If UI changes detected, note that screenshots should be added]
```

Create PR using GitHub CLI:
```bash
gh pr create --title "[commit message]" --body "[generated description]" --base main
```

---

## Step 4: Verify CI Pipeline

After creating the PR, check if CI pipeline passes:

```bash
# Wait briefly for CI to start, then check status
sleep 10
gh pr checks $(gh pr view --json number -q .number) 2>/dev/null || echo "CI status not available yet"
```

If CI checks are available:
- Show status of each check (lint, test, build, security)
- If any check fails, report the failure and suggest: `/debug <failure-details>`

If CI not configured:
- Suggest: `/gen-ci github-actions` to set up CI/CD pipeline

---

## Step 5: Update Sprint Plan (if exists)

After successful ship:

```
1. Check if SPRINT_PLAN.md exists in the project root
2. If found:
   a. Parse the commit message for task references (e.g., "feat(1.3):" or "task 1.3")
   b. If no explicit task reference, try to match by:
      - Changed file names against sprint task descriptions
      - Commit type against task type (feat → feature tasks, fix → bug tasks)
   c. Update matched tasks: ⬜ → ✅ (mark as shipped)
   d. Update sprint progress counters
   e. Print sprint progress summary:
      "Sprint 2 Progress: 8/12 tasks completed (67%)"
3. If not found: skip silently
```

## Step 5b: Update Jira (if connected)

If a Jira project is configured (`.cortex/jira.json`) or the Atlassian MCP server is
connected, the `jira-integration` skill closes the loop:

```
1. Resolve the issue key from: the branch name (feature/PROJ-123-...), the commit
   message, or AUTO_BUILD_STATE.json.
2. addCommentToJiraIssue → post the PR URL + one-line summary.
3. transitionJiraIssue → "In Review" (or "Done" if the user opted in), using a real
   transition ID from getTransitionsForJiraIssue.
4. If Jira isn't connected or no key is found: skip silently (never block the ship).
```

---

## Step 6: Summary

```
╔══════════════════════════════════════════════════════════════╗
║  SHIPPED ✅                                                   ║
╠══════════════════════════════════════════════════════════════╣
║  Commit: [hash] [message]                                    ║
║  Branch: [branch] → main                                     ║
║  PR: [url]                                                   ║
║                                                               ║
║  Code Review: [n] blockers fixed, [n] warnings noted         ║
║  Tests: ✅ [n] passing                                       ║
║  CI Pipeline: ✅ passing / ⏳ pending / ❌ failing           ║
║                                                               ║
║  Sprint Progress: [n]/[total] tasks ([%]%)                   ║
╚══════════════════════════════════════════════════════════════╝
```

---
description: "Guided feature development from spec to PR with sprint plan tracking. Usage: /feature <feature-description-or-sprint-task-id>"
---

# Guided Feature Development

Build feature: **$ARGUMENTS**

---

## Phase 0: Sprint Plan Integration

Before starting, check if this feature maps to a sprint task:

```
0. If $ARGUMENTS looks like a Jira issue key (matches ^[A-Z][A-Z0-9]+-\d+$, e.g. "PROJ-123"):
   → The `jira-integration` skill handles it: read the issue via the Atlassian MCP
     server, use its summary + description + acceptance criteria as the feature spec,
     and transition the issue to "In Progress". Then continue the flow below.
   → If Jira isn't connected, fall back to treating $ARGUMENTS as a plain description.
1. Check if SPRINT_PLAN.md exists
2. If $ARGUMENTS references a task ID (e.g., "task 2.3", "sprint task 2.3", or just "2.3"):
   a. Read SPRINT_PLAN.md
   b. Find the matching task
   c. Verify its dependencies are completed (all blockedBy tasks are ✅)
   d. If blocked: "⚠️ Task 2.3 is blocked by task 2.1 (not yet completed). Build task 2.1 first?"
   e. If unblocked: Mark task as 🔄 (in progress) in SPRINT_PLAN.md
   f. Use the task's description as the feature specification
3. If $ARGUMENTS is a description (not a task ID):
   a. Search SPRINT_PLAN.md for a matching task by description similarity
   b. If found: "Found matching sprint task 2.3. Linking this feature to it."
   c. Mark as 🔄 in SPRINT_PLAN.md
4. If no SPRINT_PLAN.md exists: proceed normally without sprint tracking
```

---

## Phase 1: Planning

**SCOPE CHECK (CRITICAL):** If the feature is too large (would touch 5+ files or take more than 2 hours), SPLIT it into micro-tasks first:
- Each micro-task = ONE file or ONE logical unit (max 2 hours)
- Present the split to the user: "This feature is large. I'll break it into X micro-tasks and build them one by one."
- Build each micro-task with its own commit
- This prevents context window exhaustion

1. **Understand the requirement** — Parse the feature description (or sprint task spec)
2. **Explore existing code** — Find related modules, patterns, and conventions
3. **Create a plan** — Generate a step-by-step implementation plan:

```markdown
# Feature Plan: [feature name]
## Sprint Task: [task ID if linked] — [sprint name]

## Affected Files
- [ ] file1.py — [what changes]
- [ ] file2.py — [what changes]
- [ ] NEW: file3.py — [purpose]

## Dependencies
- External packages needed: [list]
- Internal modules used: [list]
- Sprint task dependencies: [list of completed prerequisite tasks]

## Database Changes
- Migrations needed: [yes/no]
- Schema changes: [details]

## API Changes
- New endpoints: [list]
- Modified endpoints: [list]
- Breaking changes: [yes/no]

## Estimated Complexity
[Low / Medium / High] — [reasoning]
[Story Points: X] (from sprint plan if linked)
```

Present the plan and **ask for confirmation** before proceeding.

---

## Phase 2: Implementation

**⚡ CONTEXT MANAGEMENT**: Delegate code writing to Agent subagents to keep the main context clean. For each file group, spawn a Agent subagent with the file list, patterns to follow, and verify command.

1. Create a feature branch:
```bash
git checkout -b feature/[slugified-name]
# If sprint task linked: feature/sprint-2-task-2.3-[name]
```

2. **Delegate implementation to Agent subagent(s):**
   - Spawn Agent subagent (mode = "bypassPermissions") with: file list from plan, project patterns, Alpha AI rules
   - Subagent writes code following existing project patterns
   - Subagent follows Alpha AI layer segregation: api/ → services/ → repositories/
   - **If the feature touches the frontend:** copy the production bar from
     `skills/alpha-architecture/references/CODE_PATTERNS_FRONTEND_PRODUCTION.md`
     inline into the subagent prompt (subagents can't read references) — real
     next/font pairing + OKLCH semantic tokens (no system fonts / raw hex /
     bg-blue-500), real-data wiring with all 4 states, friendly branded errors
     via the project's `getErrorMessage` mapper (NEVER show HTTP codes,
     exceptions, stack traces, or raw API payloads). Reuse the existing
     BRAND_GUIDE/token system — never invent new colors.
   - Subagent verifies lint + compile before reporting back
   - If multiple independent files: spawn parallel subagents

3. After subagent returns, verify it compiles/lints in main context.

---

## Phase 3: Testing

1. Generate tests for all new code (use /gen-tests patterns)
2. Run the full test suite to ensure no regressions
3. Add integration tests if the feature touches multiple modules
4. Target: >80% coverage on new code

---

## Phase 4: Documentation

1. Update README if the feature adds user-facing functionality
2. Add docstrings for new public APIs
3. Update CHANGELOG.md
4. Update CLAUDE.md if architecture changed
5. Update API docs if new endpoints added

---

## Phase 5: Review & Ship

1. Run automated code review on the changes:
   - Security: no hardcoded secrets, proper auth, input validation
   - Performance: no N+1, proper caching, async I/O
   - Quality: no code smells, proper error handling
   - Alpha AI compliance: layer rules, tech stack, naming conventions

2. Fix any issues found

3. Commit with a clear conventional commit message:
   ```
   feat(scope): description

   Sprint-Task: 2.3
   ```

4. Provide a summary of everything implemented

---

## Phase 6: Update Sprint Plan

After feature is complete:

```
1. If SPRINT_PLAN.md is linked:
   a. Update task status: 🔄 → ✅
   b. Record completion date
   c. Update sprint progress:
      "Sprint 2: 9/12 tasks completed (75%) — 3 remaining"
   d. Check if any blocked tasks are now unblocked:
      "✅ Task 2.3 complete → Task 2.5 is now unblocked"
   e. Suggest next task:
      "Next available task: 2.4 — [description] (S, 2 points)"

2. Print sprint progress summary
```

---

## Output

```
╔══════════════════════════════════════════════════════════════╗
║  FEATURE COMPLETE: [feature name]                            ║
╠══════════════════════════════════════════════════════════════╣
║                                                               ║
║  Files Created: [n]                                          ║
║  Files Modified: [n]                                         ║
║  Tests Added: [n]                                            ║
║  Test Coverage: [%] on new code                              ║
║                                                               ║
║  Sprint Task: [task ID] ✅ Completed                         ║
║  Sprint Progress: [n]/[total] ([%]%)                         ║
║  Next Task: [task ID] — [description]                        ║
║                                                               ║
║  Next: /ship "[commit message]" to create PR                 ║
╚══════════════════════════════════════════════════════════════╝
```

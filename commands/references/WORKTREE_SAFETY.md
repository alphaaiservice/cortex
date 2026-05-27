# Worktree Safety — Pre-Flight Pattern for Risky File-Mutation Commands

> **This file is referenced by commands that mutate many files at once** (e.g.
> `/migrate-stack`, `/refactor`, `/retrofit`). It defines the safety decision
> tree they MUST follow before any mutations. Do NOT skip it for "quick" runs —
> the time saved is dwarfed by the time lost to a botched mutation.

---

## Why this exists

Commands like `/migrate-stack`, `/refactor`, and `/retrofit` rewrite many
files at once. A bad run can:

- Mix the command's changes into the user's in-flight uncommitted work,
  making both impossible to untangle.
- Leave the working tree in a half-migrated state if the run is interrupted
  (compaction, context loss, manual cancel) — the user has no clean rollback.
- Touch files outside the user's intent because of overly broad globs.

Running in an isolated git worktree prevents all three failure modes: the
user's main checkout is untouched until they explicitly accept the diff.

---

## The Safety Decision Tree (run BEFORE any mutations)

### Step 1 — Confirm scope with the user

Before any file write, tell the user:

- Which command is about to run.
- Which files / directories / modules are in scope.
- What classes of change to expect (e.g. "rename N symbols, decompose M
  functions, mutate L config files").

Then ask which execution mode they want:

| Option | When to use | Trade-off |
|--------|-------------|-----------|
| **Isolated worktree** (DEFAULT) | Almost always | Safest. User reviews a diff before anything lands in their main checkout. |
| **Current checkout** | User explicitly opts in for speed and accepts risk | Faster, but a bad run contaminates the working tree. Refuse if the tree is dirty. |
| **Cancel** | Always available | Walks away with no changes. |

### Step 2a — Isolated worktree (DEFAULT)

Prefer this. Two implementations, in order of preference:

**Option A: Spawn the mutation phase as a subagent with worktree isolation.**

```
Agent({
  subagent_type: "general-purpose",
  isolation: "worktree",
  description: "...",
  prompt: "Execute the mutation phase of /<command>. ..."
})
```

The harness creates a temporary worktree, runs the subagent there, and
returns the worktree path + branch name when it finishes. If the subagent
makes no changes the worktree is auto-cleaned. This is the cleanest pattern
when the mutation phase is parallelizable or self-contained.

**Option B: Manual worktree (when not delegating).**

```bash
WORKTREE_DIR="../$(basename "$PWD")-<command>-$(date +%s)"
BRANCH="<command>/auto-$(date +%Y%m%d-%H%M%S)"
git worktree add "$WORKTREE_DIR" -b "$BRANCH"
cd "$WORKTREE_DIR"
# ... do all mutations here ...
```

After the work completes (either Option A or B):

1. Surface the diff: `git diff main..HEAD --stat` then `git log main..HEAD --oneline`.
2. Offer the user three choices: **merge** (`git merge --no-ff <branch>` from main),
   **cherry-pick** (let them pick which commits to take), or **discard** (`git worktree
   remove <path>` + `git branch -D <branch>`).
3. Never auto-merge into main without explicit user approval.

### Step 2b — Current checkout (user accepted the risk)

If the user explicitly chose to run in the current checkout:

1. **Verify the working tree is clean.** Run `git status --porcelain`. If
   the output is non-empty, **stop**. Ask the user to commit or stash
   their in-flight work first — never mix this command's changes with
   the user's own.
2. **Create a savepoint commit** before any mutation:
   ```bash
   git commit --allow-empty -m "savepoint: before /<command> $ARGUMENTS"
   ```
   Rollback path is then `git reset --hard HEAD~1` (single command, no
   reflog hunting).
3. Proceed with the mutations on the current branch.

### Step 2c — No git at all

Stop. Refuse to proceed. Mutating this many files without git is reckless
— there is no rollback path if the run goes wrong. Ask the user to
`git init` first or to run the command inside a checked-out repo.

---

## Quick checklist for the command author

A command that includes worktree safety MUST:

- [ ] Reference this file in its Step 0 (`commands/references/WORKTREE_SAFETY.md`).
- [ ] Run the decision tree BEFORE any `Write` / `Edit` / `Bash` mutation.
- [ ] Default to the isolated-worktree option when the user has no preference.
- [ ] Refuse to mutate a dirty working tree without an explicit user OK.
- [ ] Never auto-merge back to `main` — always require explicit approval.
- [ ] On any error mid-mutation, leave the worktree intact for inspection
      (do NOT auto-clean), and tell the user where it lives.

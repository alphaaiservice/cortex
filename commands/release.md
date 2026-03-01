---
description: "Automate releases: bump version, generate changelog, create git tag, and publish GitHub/GitLab release. Usage: /release [major|minor|patch] [--dry-run]"
---

# Release Management Automation

$ARGUMENTS = version bump type (major/minor/patch), specific version (e.g., "2.0.0-beta.1"), or optional flags (--dry-run).

Parse $ARGUMENTS to determine:
- **Bump type**: `major`, `minor`, `patch`, or a specific semver string
- **Dry run mode**: if `--dry-run` is present, simulate everything but do NOT execute any writes, commits, tags, or pushes
- **Default**: if no argument given, auto-detect bump type from commit messages since last release

---

## Step 1: Determine Current Version

Search for the current version in this priority order. Stop at the first source found:

### 1a. Check pyproject.toml
```bash
grep -E '^version\s*=' pyproject.toml 2>/dev/null | head -1 | sed 's/.*"\(.*\)".*/\1/'
```

### 1b. Check package.json
```bash
node -e "console.log(require('./package.json').version)" 2>/dev/null
```

### 1c. Check VERSION file
```bash
cat VERSION 2>/dev/null | tr -d '[:space:]'
```

### 1d. Check setup.cfg
```bash
grep -E '^version\s*=' setup.cfg 2>/dev/null | head -1 | sed 's/.*=\s*//' | tr -d '[:space:]'
```

### 1e. Check Cargo.toml (Rust)
```bash
grep -E '^version\s*=' Cargo.toml 2>/dev/null | head -1 | sed 's/.*"\(.*\)".*/\1/'
```

### 1f. Check latest git tag
```bash
git describe --tags --abbrev=0 --match "v*" 2>/dev/null | sed 's/^v//'
```

### 1g. Fallback
If no version is found anywhere, start at `0.1.0` and inform the user that this is an initial release.

Record:
- `CURRENT_VERSION` = the version found
- `VERSION_SOURCE` = which file/method provided it (e.g., "pyproject.toml", "git tag", "fallback")

Print:
```
[INFO] Current version: CURRENT_VERSION (from VERSION_SOURCE)
```

---

## Step 2: Calculate New Version (Semantic Versioning)

### 2a. If specific version provided in $ARGUMENTS
If $ARGUMENTS contains a semver string (e.g., `2.0.0`, `1.5.0-beta.1`, `3.0.0-rc.2`), validate it:
- Must match pattern: `MAJOR.MINOR.PATCH` with optional `-prerelease.N` or `+build`
- Must be greater than CURRENT_VERSION (unless it is a pre-release of a higher version)
- If invalid, report the error and STOP

Use the provided version directly as `NEW_VERSION`.

### 2b. If bump type provided (major/minor/patch)
Parse CURRENT_VERSION as `MAJOR.MINOR.PATCH`:

- **patch**: `MAJOR.MINOR.(PATCH+1)` -- e.g., 1.2.3 -> 1.2.4
- **minor**: `MAJOR.(MINOR+1).0` -- e.g., 1.2.3 -> 1.3.0
- **major**: `(MAJOR+1).0.0` -- e.g., 1.2.3 -> 2.0.0

### 2c. Auto-detect from commits (no argument given)
Fetch all commit messages since the last tag:
```bash
LAST_TAG=$(git describe --tags --abbrev=0 --match "v*" 2>/dev/null || echo "")
if [ -z "$LAST_TAG" ]; then
  COMMITS=$(git log --oneline --format="%s")
else
  COMMITS=$(git log ${LAST_TAG}..HEAD --oneline --format="%s")
fi
```

Analyze the commit messages using Conventional Commits:
- If ANY commit contains `BREAKING CHANGE:` in the body/footer OR uses `!:` in the subject (e.g., `feat!:`, `fix!:`, `refactor!:`) --> **major**
- If ANY commit starts with `feat:` or `feat(` --> **minor**
- If ALL commits are `fix:`, `docs:`, `chore:`, `style:`, `refactor:`, `perf:`, `test:`, `ci:`, `build:` --> **patch**
- If no conventional commits are found at all, default to **patch** and warn the user

Print:
```
[INFO] Auto-detected bump type: [major/minor/patch] based on [N] commits since [LAST_TAG or "initial"]
[INFO] Version bump: CURRENT_VERSION -> NEW_VERSION
```

### 2d. Pre-release version handling
If the current version already contains a pre-release suffix (e.g., `2.0.0-beta.1`):
- `patch` bumps the pre-release number: `2.0.0-beta.1` -> `2.0.0-beta.2`
- `minor` or `major` strips the pre-release: `2.0.0-beta.1` -> `2.0.0` (release)
- Inform the user of the pre-release handling logic applied

### 2e. Version confirmation
Print the planned version change clearly:
```
[PLAN] Version: CURRENT_VERSION -> NEW_VERSION (bump type)
```

---

## Step 3: Pre-Release Checks

Run all checks and collect results. Do NOT stop on the first failure -- run all checks and report a summary.

### 3a. Uncommitted changes check
```bash
if [ -n "$(git status --porcelain)" ]; then
  echo "FAIL: Working directory has uncommitted changes"
  git status --short
else
  echo "PASS: Working directory is clean"
fi
```
**If dirty**: List the files and STOP. The user must commit or stash changes before releasing. This is a hard blocker -- do NOT proceed.

### 3b. Branch check
```bash
CURRENT_BRANCH=$(git branch --show-current)
echo "Current branch: $CURRENT_BRANCH"
```
- If on `main` or `master`: PASS
- If on `release/*` or `hotfix/*`: PASS (these are valid release branches)
- If on any other branch: WARN (not a blocker, but inform the user and ask for confirmation)

### 3c. Remote sync check
```bash
git fetch origin 2>/dev/null
LOCAL=$(git rev-parse HEAD)
REMOTE=$(git rev-parse origin/$(git branch --show-current) 2>/dev/null || echo "no-remote")
if [ "$LOCAL" = "$REMOTE" ]; then
  echo "PASS: Local is in sync with remote"
elif [ "$REMOTE" = "no-remote" ]; then
  echo "WARN: No remote tracking branch found"
else
  BEHIND=$(git rev-list HEAD..origin/$(git branch --show-current) --count)
  AHEAD=$(git rev-list origin/$(git branch --show-current)..HEAD --count)
  echo "WARN: Local is $AHEAD ahead and $BEHIND behind remote"
fi
```
**If behind remote**: WARN and suggest `git pull` first. This is a hard blocker if behind -- the user must pull before releasing.

### 3d. Test suite
Detect the project type and run the appropriate test suite:
```bash
echo "=== Running Tests ==="
if [ -f "pyproject.toml" ] || [ -f "setup.py" ] || [ -f "setup.cfg" ]; then
  python -m pytest --tb=short -q 2>&1
elif [ -f "package.json" ]; then
  npm test 2>&1
elif [ -f "Cargo.toml" ]; then
  cargo test 2>&1
elif [ -f "go.mod" ]; then
  go test ./... 2>&1
else
  echo "SKIP: No test framework detected"
fi
```
**If tests fail**: Report failures and STOP. Tests must pass before release.

### 3e. Linter check
```bash
echo "=== Running Linter ==="
if [ -f "pyproject.toml" ] || [ -f "setup.py" ]; then
  ruff check . 2>&1 || flake8 . 2>&1 || echo "SKIP: No Python linter found"
elif [ -f "package.json" ]; then
  npx eslint . --max-warnings=0 2>&1 || npm run lint 2>&1 || echo "SKIP: No JS linter configured"
elif [ -f "Cargo.toml" ]; then
  cargo clippy -- -D warnings 2>&1 || echo "SKIP: clippy not available"
fi
```
**If lint errors**: WARN (not a hard blocker, but report the count and advise fixing)

### 3f. Type checking
```bash
echo "=== Type Checking ==="
if [ -f "tsconfig.json" ]; then
  npx tsc --noEmit 2>&1
elif [ -f "pyproject.toml" ] && grep -q "mypy" pyproject.toml 2>/dev/null; then
  mypy . 2>&1 || echo "SKIP: mypy not configured"
fi
```
**If type errors**: WARN (not a hard blocker)

### 3g. Security audit
```bash
echo "=== Security Audit ==="
if [ -f "package-lock.json" ]; then
  npm audit --audit-level=high 2>&1
elif [ -f "requirements.txt" ] || [ -f "pyproject.toml" ]; then
  pip audit 2>&1 || safety check 2>&1 || echo "SKIP: No Python security scanner found"
elif [ -f "Cargo.toml" ]; then
  cargo audit 2>&1 || echo "SKIP: cargo-audit not installed"
fi
```
**If critical vulnerabilities**: WARN and list them

### 3h. TODO/FIXME check in critical paths
```bash
echo "=== Checking for TODO/FIXME in critical files ==="
grep -rn "TODO\|FIXME\|HACK\|XXX\|WORKAROUND" \
  --include="*.py" --include="*.ts" --include="*.js" --include="*.rs" --include="*.go" \
  --exclude-dir=node_modules --exclude-dir=.venv --exclude-dir=target --exclude-dir=vendor \
  src/ app/ lib/ core/ 2>/dev/null | head -20
```
**If found**: WARN with count and list (not a blocker, informational only)

### 3i. Pre-Release Check Report

Print a consolidated report:
```
+------------------------------------------------------+
|              PRE-RELEASE CHECK REPORT                |
+------------------------------------------------------+
| Version:          CURRENT_VERSION -> NEW_VERSION     |
| Bump Type:        [major/minor/patch]                |
| Branch:           [branch-name]                      |
+------------------------------------------------------+
| Git Clean:        PASS / FAIL (blocker)              |
| Branch OK:        PASS / WARN                        |
| Remote Sync:      PASS / WARN / FAIL (blocker)      |
| Tests:            PASS / FAIL (blocker) / SKIP       |
| Linter:           PASS / WARN / SKIP                 |
| Type Check:       PASS / WARN / SKIP                 |
| Security:         PASS / WARN / SKIP                 |
| TODO/FIXME:       [count] found (info)               |
+------------------------------------------------------+
| Overall:          READY / BLOCKED                    |
+------------------------------------------------------+
```

If any blocker is FAIL: STOP and report what needs to be fixed.
If only warnings exist: Inform the user and proceed (they can re-run with fixes if desired).

---

## Step 4: Generate Changelog

### 4a. Gather commits since last release
```bash
LAST_TAG=$(git describe --tags --abbrev=0 --match "v*" 2>/dev/null || echo "")
if [ -z "$LAST_TAG" ]; then
  echo "[INFO] No previous tag found. Changelog will include all commits."
  GIT_LOG=$(git log --format="%H|%s|%an" --reverse)
else
  echo "[INFO] Generating changelog since $LAST_TAG"
  GIT_LOG=$(git log ${LAST_TAG}..HEAD --format="%H|%s|%an" --reverse)
fi
```

### 4b. Parse Conventional Commits into categories

Categorize each commit by its type prefix:

| Prefix | Category | Emoji |
|--------|----------|-------|
| `feat:` or `feat(...):`  | New Features | (rocket) |
| `fix:` or `fix(...):`    | Bug Fixes | (bug) |
| `perf:` or `perf(...):`  | Performance | (zap) |
| `refactor:` or `refactor(...):` | Improvements | (wrench) |
| `docs:` or `docs(...):`  | Documentation | (books) |
| `test:` or `test(...):`  | Tests | (test tube) |
| `style:` or `style(...):` | Code Style | (art) |
| `ci:` or `ci(...):`      | CI/CD | (construction worker) |
| `build:` or `build(...):` | Build System | (package) |
| `chore:` or `chore(...):` | Chores | (broom) |
| `revert:` or `revert(...):` | Reverts | (rewind) |
| `BREAKING CHANGE` or `!:` | Breaking Changes | (warning) |
| Everything else          | Other Changes | (pushpin) |

Also extract:
- PR/issue references: `(#123)` patterns
- Scope: `feat(auth):` -> scope is `auth`
- Contributors: unique commit authors

### 4c. Detect breaking changes
Scan both commit subjects AND commit bodies for:
- `BREAKING CHANGE:` footer
- `!:` in subject (e.g., `feat!: remove legacy API`)
- `BREAKING:` anywhere in message

### 4d. Build changelog section

Format the changelog entry as follows:

```markdown
## [vNEW_VERSION] - YYYY-MM-DD

### New Features
- feat(scope): description (#PR)
- feat: another feature (#PR)

### Bug Fixes
- fix(scope): description (#PR)

### Performance
- perf(scope): description (#PR)

### Improvements
- refactor(scope): description (#PR)

### Documentation
- docs: description (#PR)

### Tests
- test: description (#PR)

### CI/CD
- ci: description (#PR)

### Breaking Changes
- feat!: removed legacy endpoint (#PR)
  - Migration: use /api/v2/resource instead

### Other Changes
- chore: description (#PR)

### Contributors
- @author1 (N commits)
- @author2 (N commits)

**Full Changelog**: https://github.com/OWNER/REPO/compare/vOLD...vNEW
```

Rules for formatting:
- Omit empty categories (do not print a section header with no items)
- Sort commits within each category chronologically (oldest first)
- If no conventional commits found, list all commits under "Other Changes"
- Include the comparison URL only if the remote is GitHub/GitLab

### 4e. Show changelog preview
Print the generated changelog to the user before proceeding.

If `--dry-run`: Show the changelog and STOP here. Print:
```
[DRY RUN] Changelog generated. No files modified, no commits created, no tags pushed.
[DRY RUN] Run without --dry-run to execute the release.
```

---

## Step 5: Update Version Files

Update ALL version files found in the project. Track which files were modified.

### 5a. Update pyproject.toml
```bash
if [ -f "pyproject.toml" ]; then
  # Replace version = "OLD" with version = "NEW"
  sed -i.bak "s/^version = \"${CURRENT_VERSION}\"/version = \"${NEW_VERSION}\"/" pyproject.toml
  rm -f pyproject.toml.bak
  echo "[UPDATED] pyproject.toml: ${CURRENT_VERSION} -> ${NEW_VERSION}"
fi
```
Use the Write tool to make the replacement precisely. Do NOT use sed -- use Read + Write/Edit tools for accuracy.

### 5b. Update package.json
If `package.json` exists:
- Read the file
- Update the `"version"` field to `NEW_VERSION`
- Write it back preserving formatting and indentation

Also update `package-lock.json` if it exists:
```bash
if [ -f "package-lock.json" ]; then
  npm version ${NEW_VERSION} --no-git-tag-version --allow-same-version 2>/dev/null
  echo "[UPDATED] package.json + package-lock.json"
fi
```

### 5c. Update VERSION file
```bash
if [ -f "VERSION" ]; then
  echo "${NEW_VERSION}" > VERSION
  echo "[UPDATED] VERSION file"
fi
```

### 5d. Update setup.cfg
If `setup.cfg` exists and contains a `version =` line:
- Read and update the version value

### 5e. Update Cargo.toml
If `Cargo.toml` exists:
- Read and update the `version = "..."` line in the `[package]` section

### 5f. Update __init__.py or __version__.py
Search for Python version declarations:
```bash
grep -rn '__version__\s*=' --include="*.py" . 2>/dev/null | grep -v node_modules | grep -v .venv | head -5
```
If found, update each file's `__version__` to the new version.

### 5g. Update CHANGELOG.md
If `CHANGELOG.md` exists:
- Read the existing content
- Prepend the new changelog section (from Step 4) after the main heading
- Write it back

If `CHANGELOG.md` does NOT exist:
- Create it with the standard header and the first changelog section:
```markdown
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

[Generated changelog section from Step 4]
```

### 5h. Track updated files
Maintain a list of all files that were modified:
```
FILES_UPDATED = ["pyproject.toml", "CHANGELOG.md", ...]
```

Print:
```
[INFO] Updated N version files:
  - pyproject.toml
  - CHANGELOG.md
  - src/myapp/__init__.py
```

---

## Step 6: Create Git Tag + Release Commit

### 6a. Dry run gate
If `--dry-run` is active:
```
[DRY RUN] Would commit:
  git add [files]
  git commit -m "chore(release): vNEW_VERSION"
  git tag -a vNEW_VERSION -m "Release vNEW_VERSION"

[DRY RUN] Would push:
  git push origin BRANCH --tags

[DRY RUN] Would create GitHub Release:
  gh release create vNEW_VERSION --title "vNEW_VERSION" --notes "[changelog]"

[DRY RUN] No changes were made. Run without --dry-run to execute.
```
Then STOP.

### 6b. Stage version files
Stage only the files that were modified in Step 5. Do NOT use `git add -A` -- be explicit:
```bash
git add pyproject.toml CHANGELOG.md [other modified files]
```

### 6c. Create release commit
```bash
git commit -m "chore(release): v${NEW_VERSION}"
```

The commit message follows Conventional Commits format. Do NOT include `Co-Authored-By` in release commits -- this is an automated release, not a collaborative change.

### 6d. Create annotated tag
```bash
git tag -a "v${NEW_VERSION}" -m "Release v${NEW_VERSION}

$(cat <<'TAGNOTES'
[Include a brief summary from the changelog: number of features, fixes, breaking changes]
TAGNOTES
)"
```

Use an annotated tag (`-a`), not a lightweight tag. The tag message should include:
- The version number
- A brief summary (e.g., "3 features, 2 fixes, 0 breaking changes")
- Optionally the full changelog if it is short enough

### 6e. Verify the commit and tag
```bash
echo "=== Release Commit ==="
git log -1 --oneline
echo "=== Tag ==="
git tag -l "v${NEW_VERSION}" --format="%(tag) %(creatordate:short) %(subject)"
```

---

## Step 7: Publish Release

### 7a. Push to remote
```bash
BRANCH=$(git branch --show-current)
git push origin ${BRANCH} --tags
```

If the push fails:
- Check if the branch has an upstream: `git rev-parse --abbrev-ref --symbolic-full-name @{u}`
- If no upstream, set it: `git push -u origin ${BRANCH} --tags`
- If authentication fails, inform the user and provide the manual commands

### 7b. Detect hosting platform
```bash
REMOTE_URL=$(git remote get-url origin 2>/dev/null || echo "")
```
- If contains `github.com` --> GitHub
- If contains `gitlab.com` or has GitLab CI config --> GitLab
- If contains `bitbucket.org` --> Bitbucket
- Otherwise --> Unknown (skip platform-specific release creation)

### 7c. Create GitHub Release (if GitHub)
```bash
gh release create "v${NEW_VERSION}" \
  --title "v${NEW_VERSION}" \
  --notes "$(cat <<'EOF'
[Full changelog from Step 4, formatted in Markdown]
EOF
)" \
  --latest
```

If `gh` CLI is not installed or not authenticated:
```
[WARN] GitHub CLI (gh) is not available or not authenticated.
[INFO] Manual release creation URL:
  https://github.com/OWNER/REPO/releases/new?tag=v${NEW_VERSION}
[INFO] You can install gh: https://cli.github.com/
```

### 7d. Create GitLab Release (if GitLab)
```bash
# Check if glab is available
if command -v glab &>/dev/null; then
  glab release create "v${NEW_VERSION}" \
    --name "v${NEW_VERSION}" \
    --notes "[changelog]"
else
  echo "[WARN] GitLab CLI (glab) is not available."
  echo "[INFO] Create release manually at: https://gitlab.com/OWNER/REPO/-/releases/new"
fi
```

### 7e. Docker image tagging (if applicable)
Check if a Dockerfile exists:
```bash
if [ -f "Dockerfile" ] || [ -f "docker/Dockerfile" ]; then
  echo "[INFO] Dockerfile detected. Consider tagging your Docker image:"
  echo "  docker build -t REPO:v${NEW_VERSION} ."
  echo "  docker tag REPO:v${NEW_VERSION} REPO:latest"
  echo "  docker push REPO:v${NEW_VERSION}"
  echo "  docker push REPO:latest"
fi
```
Do NOT automatically build/push Docker images -- just provide the commands as guidance.

### 7f. Capture release URL
```bash
RELEASE_URL=$(gh release view "v${NEW_VERSION}" --json url -q ".url" 2>/dev/null || echo "N/A")
echo "[INFO] Release URL: ${RELEASE_URL}"
```

---

## Step 8: Post-Release

### 8a. Bump to next development version (optional)
Ask the user if they want to bump to the next development version:
```
[OPTIONAL] Bump to next development version?
  Current release: NEW_VERSION
  Next dev version: NEW_VERSION with patch+1 and -dev suffix
  Example: 1.3.0 -> 1.3.1-dev

This creates a commit marking the start of the next development cycle.
```

If the user agrees (or if this is an automated pipeline), do the bump:
- Calculate next dev version: increment patch by 1, add `-dev` suffix
- Update version files with the dev version
- Commit: `chore: bump version to X.Y.Z-dev [skip ci]`

If the user declines or does not respond, skip this step.

### 8b. Webhook notification (if configured)
Check for notification configuration:
```bash
# Check for .release-notify or release config in pyproject.toml
if [ -f ".release-notify" ]; then
  WEBHOOK_URL=$(cat .release-notify | grep webhook_url | cut -d= -f2 | tr -d '[:space:]')
  if [ -n "$WEBHOOK_URL" ]; then
    curl -s -X POST "$WEBHOOK_URL" \
      -H "Content-Type: application/json" \
      -d "{\"text\": \"Released v${NEW_VERSION}\"}" 2>/dev/null
    echo "[INFO] Notification sent to webhook"
  fi
fi
```

Check for Slack webhook:
```bash
if [ -n "$SLACK_RELEASE_WEBHOOK" ]; then
  curl -s -X POST "$SLACK_RELEASE_WEBHOOK" \
    -H "Content-Type: application/json" \
    -d "{
      \"text\": \"New Release: v${NEW_VERSION}\",
      \"blocks\": [{
        \"type\": \"section\",
        \"text\": {
          \"type\": \"mrkdwn\",
          \"text\": \"*New Release: v${NEW_VERSION}*\n${RELEASE_URL}\n\nBump: ${BUMP_TYPE}\nCommits: ${COMMIT_COUNT}\"
        }
      }]
    }" 2>/dev/null
  echo "[INFO] Slack notification sent"
fi
```

If no webhook is configured, skip silently.

### 8c. Cleanup
```bash
# Remove any backup files created during version updates
rm -f pyproject.toml.bak setup.cfg.bak Cargo.toml.bak
```

---


## Step 8.5: Update Sprint Plan (if exists)

After a successful release:

```
1. Check if SPRINT_PLAN.md exists in the project root
2. If found:
   a. Parse ALL commits included in this release for sprint task references:
      - Look for "Sprint-Task: X.Y" in commit messages
      - Look for "feat(X.Y):" or "fix(X.Y):" patterns where X.Y matches task IDs
      - Match commit descriptions against sprint task descriptions
   b. Update all matched tasks: 🔄 → ✅ (mark as released)
   c. Record the release version next to each completed task:
      "✅ Task 2.3 — User authentication [Released in v1.2.0]"
   d. Update sprint progress counters
   e. Print sprint progress:
      "Sprint [N] Progress: [completed]/[total] tasks ([percentage]%)"
   f. Check if any blocked tasks are now unblocked:
      "✅ Release v[VERSION] complete → Tasks [X], [Y] are now unblocked"
   g. If ALL tasks in the sprint are complete:
      "🎉 Sprint [N] COMPLETE\! All [total] tasks shipped."
      "Next sprint: Sprint [N+1] — [description]"
3. If not found: skip silently
```

---

## Step 9: Output Summary

Print a comprehensive release summary:

```
+================================================================+
|                                                                |
|   RELEASE COMPLETE: vOLD_VERSION -> vNEW_VERSION               |
|                                                                |
+================================================================+
|                                                                |
|   Version:        NEW_VERSION                                  |
|   Previous:       OLD_VERSION                                  |
|   Bump Type:      [major/minor/patch]                          |
|   Date:           YYYY-MM-DD                                   |
|                                                                |
+----------------------------------------------------------------+
|                                                                |
|   Commits:        [N] since last release                       |
|   Features:       [N] new                                      |
|   Bug Fixes:      [N] fixed                                    |
|   Breaking:       [N] breaking changes                         |
|   Contributors:   [N] authors                                  |
|                                                                |
+----------------------------------------------------------------+
|                                                                |
|   Files Updated:                                               |
|     - pyproject.toml                                           |
|     - CHANGELOG.md                                             |
|     - src/myapp/__init__.py                                    |
|                                                                |
|   Git:                                                         |
|     - Commit:     [short-hash] chore(release): vNEW_VERSION    |
|     - Tag:        vNEW_VERSION                                 |
|     - Pushed:     origin/[branch]                              |
|                                                                |
|   Release:                                                     |
|     - GitHub:     [URL or N/A]                                 |
|     - Changelog:  CHANGELOG.md updated                         |
|     - Docker:     [tag commands shown / N/A]                   |
|                                                                |
|   Sprint:                                                      |
|     - Tasks Released: [N] tasks marked as shipped              |
|     - Sprint Progress: [completed]/[total] ([%]%)              |
|     - Next Task: [task ID] — [description] (if any)            |
|                                                                |
+================================================================+
```

If `--dry-run` was used, replace the summary header:
```
+================================================================+
|                                                                |
|   DRY RUN COMPLETE: vOLD_VERSION -> vNEW_VERSION               |
|   No changes were made. Run without --dry-run to execute.      |
|                                                                |
+================================================================+
```

---

## Edge Cases and Error Handling

### No git repository
If the current directory is not a git repository:
```
[ERROR] Not a git repository. Initialize with 'git init' first.
```
STOP immediately.

### No commits since last tag
If there are zero commits since the last tag:
```
[WARN] No new commits since vCURRENT_VERSION.
[INFO] There is nothing to release. Make some changes first.
```
STOP unless the user explicitly wants to re-tag.

### Merge commits
Skip merge commits when generating the changelog:
```bash
git log ${LAST_TAG}..HEAD --no-merges --format="%H|%s|%an"
```

### Tag already exists
Before creating a tag, check if it already exists:
```bash
if git rev-parse "v${NEW_VERSION}" >/dev/null 2>&1; then
  echo "[ERROR] Tag v${NEW_VERSION} already exists."
  echo "[INFO] Delete it with: git tag -d v${NEW_VERSION} && git push origin :refs/tags/v${NEW_VERSION}"
  echo "[INFO] Or choose a different version."
fi
```
STOP if the tag exists.

### Detached HEAD
If in detached HEAD state:
```
[ERROR] You are in detached HEAD state. Checkout a branch first.
  git checkout main
```
STOP immediately.

### Network failures
If `git push` or `gh release create` fails due to network:
```
[ERROR] Network operation failed. Your local state is:
  - Commit: [hash] (created)
  - Tag: vNEW_VERSION (created locally)

[INFO] To complete the release manually:
  git push origin [branch] --tags
  gh release create vNEW_VERSION --title "vNEW_VERSION" --notes-file CHANGELOG.md --latest
```

### Monorepo support
If the project appears to be a monorepo (multiple package.json/pyproject.toml files):
```
[WARN] Multiple version files detected. This may be a monorepo.
[INFO] Files found:
  - ./package.json (v1.2.3)
  - ./packages/core/package.json (v1.2.3)
  - ./packages/cli/package.json (v1.1.0)

[INFO] This release will update the ROOT version only.
[INFO] For monorepo releases, consider using dedicated tools like lerna, changesets, or turborepo.
```
Only update the root-level version file unless explicitly told otherwise.

### Protected branches
If the push is rejected due to branch protection:
```
[ERROR] Push to [branch] was rejected (branch protection rules).
[INFO] Options:
  1. Create a release branch: git checkout -b release/vNEW_VERSION
  2. Push the release branch and create a PR to merge into main
  3. Ask a repository admin to temporarily disable branch protection
```

### Empty changelog
If all commits are merge commits or have no conventional commit prefixes:
```
[WARN] No conventional commits found. Changelog will list raw commit messages.
[INFO] Consider adopting Conventional Commits: https://www.conventionalcommits.org/
```

---

## Important Notes

- This command modifies files, creates commits, creates tags, and pushes to remote. Use `--dry-run` to preview without making changes.
- Always use annotated tags (`git tag -a`) for releases, never lightweight tags.
- The changelog follows the Keep a Changelog format combined with Conventional Commits.
- Version files are updated using precise text replacement (Read + Edit tools), never blind sed commands.
- Only the files that actually exist in the project are updated -- the command adapts to the project structure.
- Release commits use the `chore(release):` prefix to distinguish them from regular commits.
- The `[skip ci]` flag is added to post-release dev version bumps to avoid triggering CI pipelines unnecessarily.

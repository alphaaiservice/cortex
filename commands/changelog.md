---
description: "Auto-generate CHANGELOG.md from git history using Conventional Commits. Groups by version, categorizes changes, links PRs. Usage: /changelog [--since=v1.0.0] [--format=keepachangelog|conventional]"
---

# Auto-Generate Changelog from Git History

$ARGUMENTS = optional flags controlling scope and output format.

Parse $ARGUMENTS to determine:
- **--since=TAG**: Start point for changelog generation (e.g., `--since=v1.0.0`). If omitted, use the latest git tag as the start point. If no tags exist, include ALL commits.
- **--format=FORMAT**: Output format — `keepachangelog` (default) or `conventional`. Keep a Changelog uses Added/Changed/Deprecated/Removed/Fixed/Security sections. Conventional uses emoji-prefixed type categories.
- **--all**: Generate changelog for the entire git history, not just since the last tag.
- **--dry-run**: Print the changelog to stdout without writing to file.
- **--output=PATH**: Custom output path (default: `CHANGELOG.md` in project root).
- **--repo-url=URL**: Override auto-detected repository URL for commit/PR links.

If no arguments are provided, default to: since last tag, keepachangelog format, write to `CHANGELOG.md`.

---

## Step 0: Pre-Flight Validation

### 0a. Verify git repository
```bash
git rev-parse --is-inside-work-tree 2>/dev/null
```
If NOT a git repository:
```
[ERROR] Not a git repository. Run 'git init' or navigate to a git project first.
```
STOP immediately.

### 0b. Check for commits
```bash
COMMIT_COUNT=$(git rev-list --count HEAD 2>/dev/null || echo "0")
```
If zero commits:
```
[ERROR] No commits found in this repository. Make some commits first.
```
STOP immediately.

### 0c. Detect repository URL for linking
```bash
REMOTE_URL=$(git remote get-url origin 2>/dev/null || echo "")
```
Parse the remote URL to construct links:
- If `github.com`: extract `OWNER/REPO` for GitHub links (`https://github.com/OWNER/REPO`)
- If `gitlab.com`: extract for GitLab links
- If `bitbucket.org`: extract for Bitbucket links
- If `--repo-url` was provided in $ARGUMENTS, use that instead
- If no remote and no override, links will be omitted (local-only mode)

Record:
- `REPO_URL` = the base URL for the repository (e.g., `https://github.com/owner/repo`)
- `PLATFORM` = `github` | `gitlab` | `bitbucket` | `local`

Print:
```
[INFO] Repository: REPO_URL (PLATFORM)
[INFO] Changelog generation starting...
```

---

## Step 1: Parse Git History

### 1a. Determine the start point

If `--since=TAG` was provided:
```bash
# Validate the tag exists
if git rev-parse "$SINCE_TAG" >/dev/null 2>&1; then
  echo "[INFO] Generating changelog since $SINCE_TAG"
  START_REF="$SINCE_TAG"
else
  echo "[ERROR] Tag '$SINCE_TAG' does not exist."
  echo "[INFO] Available tags:"
  git tag --sort=-creatordate | head -10
  # STOP
fi
```

If `--all` was provided:
```bash
echo "[INFO] Generating changelog for entire git history"
START_REF=""
```

If neither was provided (default behavior):
```bash
LAST_TAG=$(git describe --tags --abbrev=0 --match "v*" 2>/dev/null || echo "")
if [ -z "$LAST_TAG" ]; then
  # Try without v prefix
  LAST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "")
fi

if [ -n "$LAST_TAG" ]; then
  echo "[INFO] Last tag found: $LAST_TAG"
  echo "[INFO] Generating changelog since $LAST_TAG"
  START_REF="$LAST_TAG"
else
  echo "[INFO] No tags found. Generating changelog for all commits."
  START_REF=""
fi
```

### 1b. Retrieve all tags for versioned sections

When generating a full history or `--all`, collect all tags sorted by date:
```bash
git tag --sort=-creatordate --format='%(refname:short)|%(creatordate:short)|%(objectname:short)' | head -50
```

This gives us version boundaries for grouping commits into releases.

### 1c. Fetch commit data

For the determined range, fetch detailed commit information:
```bash
if [ -z "$START_REF" ]; then
  # All commits
  git log --no-merges --format="%H|%h|%s|%b|%an|%ae|%aI" --reverse
else
  # Since start ref
  git log ${START_REF}..HEAD --no-merges --format="%H|%h|%s|%b|%an|%ae|%aI" --reverse
fi
```

For each commit, extract:
- `full_hash` — full SHA for linking
- `short_hash` — abbreviated SHA for display
- `subject` — first line of commit message
- `body` — remaining lines of commit message
- `author_name` — commit author
- `author_email` — author email
- `date` — ISO 8601 date

### 1d. Parse Conventional Commits format

For each commit subject, attempt to parse using this pattern:
```
type(scope): description
type!: description (breaking)
type(scope)!: description (breaking)
type: description
```

Extract:
- **type**: `feat`, `fix`, `perf`, `refactor`, `docs`, `test`, `build`, `ci`, `chore`, `style`, `revert`, `security`
- **scope**: optional scope in parentheses (e.g., `auth`, `api`, `db`)
- **description**: the commit description after the colon
- **is_breaking**: true if `!` is present before `:` OR if body contains `BREAKING CHANGE:`
- **pr_number**: extracted from `(#123)` pattern in subject or body
- **issue_refs**: extracted from `fixes #N`, `closes #N`, `resolves #N` patterns in subject or body

### 1e. Handle non-conventional commits

If a commit does NOT match the conventional format:
- Read the commit subject and body carefully
- Use AI classification to determine the most likely type:
  - Contains words like "add", "new", "implement", "create", "introduce" --> `feat`
  - Contains words like "fix", "bug", "patch", "resolve", "correct", "repair" --> `fix`
  - Contains words like "refactor", "restructure", "reorganize", "clean up", "simplify" --> `refactor`
  - Contains words like "perf", "optimize", "speed", "fast", "improve performance" --> `perf`
  - Contains words like "doc", "readme", "comment", "typo in doc" --> `docs`
  - Contains words like "test", "spec", "coverage", "assert" --> `test`
  - Contains words like "build", "ci", "pipeline", "workflow", "deploy", "docker" --> `build`
  - Contains words like "security", "vuln", "CVE", "auth fix", "XSS", "injection" --> `security`
  - Contains words like "bump", "upgrade", "update dep", "version" --> `chore`
  - Contains words like "remove", "delete", "deprecate", "drop support" --> `chore` (mark as removal)
  - Contains words like "revert" --> `revert`
  - Anything else --> `chore`
- Mark auto-classified commits with a flag so Step 4 can annotate them

Print a summary of classification:
```
[INFO] Parsed N commits:
  - Conventional format: N commits
  - Auto-classified: N commits (verify accuracy recommended)
```

---

## Step 2: Categorize Changes

Group all parsed commits into categories. The category mapping depends on the chosen format.

### Keep a Changelog Format (`--format=keepachangelog`, default)

Map conventional commit types to Keep a Changelog sections:

| Conventional Type | Keep a Changelog Section |
|-------------------|--------------------------|
| `feat` | **Added** |
| `fix` | **Fixed** |
| `perf` | **Changed** |
| `refactor` | **Changed** |
| `docs` | **Changed** |
| `style` | **Changed** |
| `test` | *omitted (internal)* |
| `build` | *omitted (internal)* |
| `ci` | *omitted (internal)* |
| `chore` | *omitted (internal)* |
| `revert` | **Changed** |
| `security` | **Security** |
| `BREAKING CHANGE` | **Changed** (with BREAKING prefix) |
| Deprecations | **Deprecated** |
| Removals | **Removed** |

Keep a Changelog sections (in order):
1. **Added** — new features
2. **Changed** — changes in existing functionality
3. **Deprecated** — soon-to-be removed features
4. **Removed** — removed features
5. **Fixed** — bug fixes
6. **Security** — vulnerability fixes

Omit empty sections. Omit internal-only changes (test, build, ci, chore) from the public changelog unless `--include-internal` flag is provided.

### Conventional Format (`--format=conventional`)

Use emoji-prefixed categories:

| Type | Category Header |
|------|----------------|
| `feat` | New Features |
| `fix` | Bug Fixes |
| `perf` | Performance Improvements |
| `refactor` | Code Refactoring |
| `docs` | Documentation |
| `test` | Tests |
| `build`, `ci` | Build System |
| `chore` | Chores |
| `security` | Security |
| `revert` | Reverts |
| `BREAKING` | Breaking Changes |

Category display order:
1. Breaking Changes (always first if present)
2. New Features
3. Bug Fixes
4. Performance Improvements
5. Security
6. Code Refactoring
7. Documentation
8. Tests
9. Build System
10. Chores
11. Reverts

Omit empty categories.

### 2a. Collect unique contributors

Build a contributors list:
```bash
if [ -z "$START_REF" ]; then
  git log --no-merges --format="%an|%ae" | sort -u
else
  git log ${START_REF}..HEAD --no-merges --format="%an|%ae" | sort -u
fi
```

For each contributor, count their commits in this range.

### 2b. Detect and flag breaking changes

Scan ALL commits for breaking changes:
- Subject contains `!:` (e.g., `feat!:`, `fix!:`, `refactor!:`)
- Body contains `BREAKING CHANGE:` followed by description
- Body contains `BREAKING:` followed by description
- Subject or body contains `BREAKING-CHANGE:` (alternative format)

Collect breaking change descriptions separately — they get a dedicated section regardless of format.

---

## Step 3: Enrich Entries

For each commit entry, enrich it with links and metadata.

### 3a. Link to Pull Requests

Search the commit subject and body for PR references:
- Pattern: `(#123)` or `#123` — extract the number
- If `PLATFORM` is `github`: link as `[#123](REPO_URL/pull/123)`
- If `PLATFORM` is `gitlab`: link as `[!123](REPO_URL/-/merge_requests/123)`
- If `PLATFORM` is `bitbucket`: link as `[#123](REPO_URL/pull-requests/123)`
- If `PLATFORM` is `local`: show `#123` without a link

### 3b. Link to Issues

Search for issue references:
- Patterns: `fixes #456`, `closes #789`, `resolves #101`, `refs #202`
- If `PLATFORM` is `github`: link as `[#456](REPO_URL/issues/456)`
- If `PLATFORM` is `gitlab`: link as `[#456](REPO_URL/-/issues/456)`
- If `PLATFORM` is `local`: show `#456` without a link

### 3c. Author attribution

For each entry, append the author:
- If `PLATFORM` is `github`, attempt to use `@username` format
  ```bash
  # Try to get GitHub username from email
  gh api "/search/users?q=$AUTHOR_EMAIL+in:email" --jq '.items[0].login' 2>/dev/null
  ```
  If `gh` is not available or fails, fall back to the git author name.
- Format: `-- @username` or `-- Author Name`

### 3d. Link commits

For each entry, optionally link the short hash:
- If `PLATFORM` is `github`: `[short_hash](REPO_URL/commit/full_hash)`
- If `PLATFORM` is `gitlab`: `[short_hash](REPO_URL/-/commit/full_hash)`
- If `PLATFORM` is `local`: just show `short_hash`

### 3e. Scope context

If a commit has a scope, include it for clarity:
- `feat(auth): add TOTP support` --> Entry: "**auth:** Add TOTP support"
- `fix(api): handle null response` --> Entry: "**api:** Handle null response"

### 3f. Format each entry

Final entry format (Keep a Changelog):
```
- Description (#PR) -- @author
```

Final entry format (Conventional):
```
- type(scope): description (#PR) -- @author
```

If auto-classified (from Step 1e), append:
```
- Description (#PR) -- @author *(auto-classified)*
```

---

## Step 4: Generate CHANGELOG.md

### 4a. Build the header (if creating new file)

```markdown
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
```

For conventional format, replace the description:
```markdown
# Changelog

All notable changes to this project will be documented in this file.

This changelog is automatically generated from [Conventional Commits](https://www.conventionalcommits.org/).
```

### 4b. Build the version section

#### For Unreleased changes (commits since last tag):

**Keep a Changelog format:**
```markdown
## [Unreleased]

### Added
- Add TOTP two-factor authentication (#45) -- @developer1
- Add credit point top-up packs (#52) -- @developer2

### Changed
- Refactor email service to async (#50) -- @developer2
- Improve query performance for user search (#53) -- @developer1

### Fixed
- Fix null user in profile endpoint (#48) -- @developer1
- Fix race condition in token refresh (#51) -- @developer2

### Security
- Update jsonwebtoken to fix CVE-2024-XXXX (#55) -- @developer1
```

**Conventional format:**
```markdown
## [Unreleased]

### Breaking Changes
- feat(api)!: Remove legacy v1 endpoints (#60) -- @developer1
  - **Migration:** Use `/api/v2/` endpoints instead

### New Features
- feat(auth): Add TOTP two-factor authentication (#45) -- @developer1
- feat(billing): Add credit point top-up packs (#52) -- @developer2

### Bug Fixes
- fix(api): Fix null user in profile endpoint (#48) -- @developer1
- fix(auth): Fix race condition in token refresh (#51) -- @developer2

### Performance Improvements
- perf(db): Optimize user search queries with index (#53) -- @developer1

### Code Refactoring
- refactor(email): Convert email service to async (#50) -- @developer2

### Security
- security(deps): Update jsonwebtoken to fix CVE-2024-XXXX (#55) -- @developer1
```

#### For tagged releases:

Replace `[Unreleased]` with `[vX.Y.Z] - YYYY-MM-DD`:
```markdown
## [v1.2.0] - 2026-02-15
```

The date is the tag creation date:
```bash
git log -1 --format="%aI" v1.2.0 | cut -d'T' -f1
```

### 4c. Build comparison links (footer)

At the bottom of the changelog, add comparison links:

```markdown
[Unreleased]: https://github.com/OWNER/REPO/compare/v1.2.0...HEAD
[v1.2.0]: https://github.com/OWNER/REPO/compare/v1.1.0...v1.2.0
[v1.1.0]: https://github.com/OWNER/REPO/compare/v1.0.0...v1.1.0
[v1.0.0]: https://github.com/OWNER/REPO/releases/tag/v1.0.0
```

Adjust the URL pattern based on PLATFORM:
- GitHub: `compare/TAG1...TAG2`
- GitLab: `-/compare/TAG1...TAG2`
- Bitbucket: `branches/compare/TAG2..TAG1`
- Local: omit comparison links entirely

### 4d. Build contributors section (per version)

```markdown
### Contributors
- @developer1 (5 commits)
- @developer2 (3 commits)
- @developer3 (1 commit)
```

Sort contributors by commit count (descending).

### 4e. Build full changelog link

If on GitHub/GitLab, add after the last entry in each version section:
```markdown
**Full Changelog**: https://github.com/OWNER/REPO/compare/vOLD...vNEW
```

### 4f. Assemble the complete document

Combine all sections in order:
1. Header (title + description)
2. Unreleased section (if any unreleased commits exist)
3. Tagged version sections (newest first)
4. Comparison links footer

Rules:
- Omit empty categories/sections entirely (no empty headers)
- Sort commits within each category chronologically (oldest first)
- Use consistent indentation (no tabs, 2-space or 4-space)
- Ensure a blank line between sections
- End file with a newline

---

## Step 5: Handle Non-Conventional Commits

If the repository does NOT use conventional commits (majority of commits are non-conventional):

### 5a. Announce classification mode
```
[INFO] Most commits do not follow Conventional Commits format.
[INFO] Using AI-assisted classification to categorize changes.
[INFO] Auto-classified entries are marked -- verify accuracy.
```

### 5b. Classify each commit

For each non-conventional commit:
1. Read the commit subject and body
2. If available, read the diff to understand what changed:
   ```bash
   git diff $COMMIT_HASH^..$COMMIT_HASH --stat
   ```
3. Classify based on the heuristics in Step 1e
4. If the diff shows:
   - New files added --> likely `feat`
   - Only test files changed --> likely `test`
   - Only docs/README changed --> likely `docs`
   - Only config/CI files changed --> likely `build`/`ci`
   - Deletion of files/functions --> check if `refactor` or feature removal

### 5c. Mark auto-classified entries

Append `*(auto-classified)*` to entries that were AI-classified:
```markdown
- Implement user dashboard (#34) -- @developer1 *(auto-classified)*
```

### 5d. Add classification disclaimer

If more than 30% of commits were auto-classified, add a note at the top of the version section:
```markdown
> **Note:** Some entries in this section were auto-classified from non-conventional commit messages.
> Review and adjust categories as needed.
```

---

## Step 6: Update Existing CHANGELOG

### 6a. Check if CHANGELOG.md already exists
```bash
ls -la CHANGELOG.md 2>/dev/null
```

### 6b. If CHANGELOG.md EXISTS — prepend new section

Read the existing CHANGELOG.md content. Then:

1. Find the insertion point — after the header, before the first version section:
   - Look for the first `## [` line (version heading)
   - Insert the new section BEFORE that line

2. If there is an existing `## [Unreleased]` section:
   - Replace it entirely with the newly generated Unreleased section
   - Do NOT duplicate entries

3. If there is NO `## [Unreleased]` section:
   - Insert the new section after the header block

4. Update comparison links at the bottom of the file:
   - Add/update the `[Unreleased]` comparison link
   - Do NOT duplicate existing version links

5. Write the updated content back, preserving ALL existing version history.

**Critical:** NEVER overwrite or remove existing changelog entries. Only prepend or replace the Unreleased section.

### 6c. If CHANGELOG.md does NOT exist — create from scratch

Write the complete changelog with:
1. Standard header
2. Unreleased section (commits since last tag)
3. All tagged version sections (if `--all` was specified)
4. Comparison links footer

### 6d. Verify the output

After writing, verify the file is well-formed:
```bash
# Check file exists and has content
wc -l CHANGELOG.md

# Check for duplicate version headers
grep -c "^## \[" CHANGELOG.md

# Quick preview of structure
grep "^## \[" CHANGELOG.md
```

Print:
```
[INFO] CHANGELOG.md written successfully
[INFO] File size: N lines
[INFO] Version sections: N
```

---

## Step 7: Handle --dry-run

If `--dry-run` was specified in $ARGUMENTS:

1. Print the generated changelog content to stdout (do NOT write to file)
2. Show the summary (Step 8) with a dry-run indicator
3. Print:
```
[DRY RUN] Changelog generated but NOT written to file.
[DRY RUN] Run without --dry-run to write CHANGELOG.md.
```

STOP after printing. Do not modify any files.

---

## Step 8: Output Summary

Print a comprehensive generation summary:

```
+==============================================================+
|  CHANGELOG GENERATED                                         |
+==============================================================+
|  Commits Processed: [total count]                            |
|  +-- Features:       [n]                                     |
|  +-- Fixes:          [n]                                     |
|  +-- Performance:    [n]                                     |
|  +-- Refactoring:    [n]                                     |
|  +-- Documentation:  [n]                                     |
|  +-- Security:       [n]                                     |
|  +-- Tests:          [n]                                     |
|  +-- Build/CI:       [n]                                     |
|  +-- Chores:         [n]                                     |
|  +-- Reverts:        [n]                                     |
|  +-- Other:          [n]                                     |
|                                                              |
|  Breaking Changes:   [n]                                     |
|  Auto-Classified:    [n] (verify recommended)                |
|  Contributors:       [n]                                     |
|                                                              |
|  Format:             [keepachangelog / conventional]          |
|  Range:              [tag]..HEAD / full history               |
|  Version Sections:   [n]                                     |
|                                                              |
|  Output: CHANGELOG.md ([n] lines)                            |
+==============================================================+
```

If `--dry-run`:
```
+==============================================================+
|  CHANGELOG PREVIEW (DRY RUN -- no files modified)            |
+==============================================================+
|  [same stats as above]                                       |
+==============================================================+
```

---

## Edge Cases and Error Handling

### Empty commit range
If there are no commits in the specified range:
```
[WARN] No commits found since [tag/ref].
[INFO] Nothing to add to the changelog.
```
STOP without modifying files.

### Extremely large history
If more than 500 commits are in the range:
```
[INFO] Processing [N] commits. This may take a moment...
```
Process in batches of 100 commits to avoid shell argument limits.

### Binary-only commits
If a commit only changes binary files (images, compiled assets):
- Classify as `chore` unless the commit message says otherwise
- Note: "Update binary assets" or similar

### Revert commits
If a commit is a revert (subject starts with `Revert "..."`):
- Place in the **Reverts** category (conventional) or **Changed** (keepachangelog)
- Reference the original commit being reverted
- Format: `Revert "original commit subject" (#PR) -- @author`

### Squash merge commits
If the repository uses squash merges, commit bodies often contain the full PR description. Extract:
- The PR number from the subject (usually appended as `(#123)`)
- Individual changes listed in the body (bullet points)
- Use the body content to enrich the entry

### Monorepo / scoped commits
If many commits have scopes (e.g., `feat(web):`, `fix(api):`), consider grouping by scope as sub-sections:
```markdown
### Added

#### api
- Add user search endpoint (#45) -- @developer1

#### web
- Add dashboard page (#46) -- @developer2
```

Only activate scope grouping if more than 10 commits have scopes AND there are 3+ distinct scopes. Otherwise, use flat listing with bold scope prefix.

### No remote URL
If no git remote is configured and no `--repo-url` override:
```
[INFO] No git remote detected. Generating changelog without links.
[INFO] To add links, use: /changelog --repo-url=https://github.com/owner/repo
```

### Existing changelog with non-standard format
If an existing CHANGELOG.md does not follow Keep a Changelog or Conventional format:
```
[WARN] Existing CHANGELOG.md does not follow a recognized format.
[INFO] Prepending new section at the top. Existing content preserved below.
[INFO] Consider reformatting the entire file with: /changelog --all
```

### Protected or read-only file
If CHANGELOG.md cannot be written:
```
[ERROR] Cannot write to CHANGELOG.md. Check file permissions.
[INFO] Printing changelog to stdout instead:
```
Then print the content to stdout as a fallback.

---

## Important Notes

- This command ONLY modifies CHANGELOG.md (or the file specified by `--output`). It does NOT create commits, tags, or push anything.
- Merge commits are excluded by default (`--no-merges`) to avoid noise.
- The changelog is generated from git history — it is only as good as the commit messages. Repositories using Conventional Commits will get the best results.
- Auto-classification uses heuristics and AI judgment. Always review auto-classified entries for accuracy.
- When updating an existing CHANGELOG.md, existing entries are NEVER modified or removed. Only new content is prepended.
- Comparison links at the bottom of the file are maintained automatically.
- For the best experience, use this command in combination with `/release` which handles version bumping, tagging, and changelog generation as part of a release workflow.
- The `--all` flag can be used to regenerate the complete changelog from scratch, but use with caution on repositories with long histories as it will replace the entire file.

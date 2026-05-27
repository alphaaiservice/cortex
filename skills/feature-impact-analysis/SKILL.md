---
name: feature-impact-analysis
description: "Auto-invoked when user discusses schema changes, database migrations, feature removal, refactoring, API deprecation, or dependency updates. Traces dependencies across the full stack (table -> service -> API -> frontend component), generates blast radius reports with severity levels, and suggests ordered migration plans. Works for ANY stack: Python/FastAPI, Node.js/NestJS, Java/Spring Boot, React, React Native."
license: "Proprietary — Alpha AI Service Pvt Ltd"
compatibility: "Designed for Claude Code with cortex plugin"
metadata:
  author: "Alpha AI Service Pvt Ltd"
  version: "1.0"
---

# Feature Impact Analysis — Full-Stack Blast Radius Detection

This skill systematically traces the impact of any proposed change across the entire stack. It works for schema changes, API changes, feature removal, dependency updates, and refactoring operations.

---

## Step 0: Identify the Change Type

Classify the proposed change:

| Change Type | Trigger Phrases | Analysis Focus |
|---|---|---|
| Schema Change | "add column", "remove column", "rename table", "change type", "migration" | DB -> ORM -> Service -> API -> Frontend |
| API Change | "deprecate endpoint", "change response", "rename route", "v2 API" | API -> Frontend -> Mobile -> External consumers |
| Feature Removal | "remove feature", "delete module", "deprecate", "sunset" | Feature -> All dependents across full stack |
| Dependency Update | "upgrade library", "bump version", "replace package" | Package -> All importers -> Breaking changes |
| Refactor | "rename", "move", "extract", "split module", "merge" | Symbol -> All references across codebase |
| Config Change | "change env var", "update config", "modify settings" | Config -> All consumers across services |

---

## Step 1: Map the Dependency Graph

### 1a — Schema Change Analysis

When a database schema change is proposed, trace ALL code that references the affected tables/columns:

```bash
# Step 1: Find all ORM model references to the affected table
grep -rn "tablename.*=.*['\"]AFFECTED_TABLE['\"]" --include="*.py" .
grep -rn "@Entity.*AFFECTED_TABLE\|@Table.*AFFECTED_TABLE" --include="*.java" .
grep -rn "model.*AFFECTED_TABLE\|schema.*AFFECTED_TABLE" --include="*.ts" --include="*.prisma" .

# Step 2: Find all code referencing the affected column
grep -rn "AFFECTED_COLUMN" --include="*.py" --include="*.ts" --include="*.java" --include="*.sql" .

# Step 3: Find all repository/DAO methods using the table
grep -rn "select.*AFFECTED_TABLE\|insert.*AFFECTED_TABLE\|update.*AFFECTED_TABLE\|delete.*AFFECTED_TABLE" --include="*.py" --include="*.ts" --include="*.java" --include="*.sql" .

# Step 4: Find all service files importing the repository
# (trace from repository -> service -> API -> frontend)

# Step 5: Find migration files referencing the table
grep -rn "AFFECTED_TABLE" --include="*.py" --include="*.ts" --include="*.sql" migrations/ alembic/ prisma/ 2>/dev/null
```

### 1b — API Change Analysis

When an API endpoint is being changed or removed:

```bash
# Step 1: Find the route definition
grep -rn "\"AFFECTED_PATH\"\|'AFFECTED_PATH'" --include="*.py" --include="*.ts" --include="*.java" .

# Step 2: Find all frontend API calls to this endpoint
grep -rn "AFFECTED_PATH" --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" .

# Step 3: Find mobile app API calls
grep -rn "AFFECTED_PATH" --include="*.ts" --include="*.tsx" --include="*.swift" --include="*.kt" .

# Step 4: Find test files referencing this endpoint
grep -rn "AFFECTED_PATH" --include="*.test.*" --include="*_test.*" --include="*.spec.*" .

# Step 5: Find API documentation referencing this endpoint
grep -rn "AFFECTED_PATH" --include="*.md" --include="*.yaml" --include="*.json" docs/ 2>/dev/null
```

### 1c — Feature Removal Analysis

When an entire feature is being removed:

```bash
# Step 1: Find the feature's primary directory/files
find . -path "*FEATURE_NAME*" -not -path "*/node_modules/*" -not -path "*/.git/*"

# Step 2: Find all imports FROM the feature module
grep -rn "from.*FEATURE_NAME.*import\|import.*FEATURE_NAME\|require.*FEATURE_NAME" --include="*.py" --include="*.ts" --include="*.java" .

# Step 3: Find all references to feature's exported symbols
# (extract exports first, then search for each)

# Step 4: Find configuration referencing the feature
grep -rn "FEATURE_NAME" --include="*.env*" --include="*.yml" --include="*.yaml" --include="*.json" --include="*.toml" .

# Step 5: Find routes/navigation referencing the feature
grep -rn "FEATURE_NAME\|/feature-path" --include="*.py" --include="*.ts" --include="*.tsx" .

# Step 6: Find database tables/collections owned by this feature
grep -rn "tablename\|@Entity\|model\|collection" --include="*.py" --include="*.ts" --include="*.java" FEATURE_DIR/
```

---

## Step 2: Build the Impact Tree

For each affected file/component, classify the impact level:

### Severity Classification

| Level | Criteria | Icon |
|---|---|---|
| **CRITICAL** | Direct breakage: code will crash, queries will fail, data will be lost | [CRITICAL] |
| **HIGH** | Functional breakage: feature will not work correctly, data inconsistency risk | [HIGH] |
| **MEDIUM** | Degraded functionality: partial feature loss, UI shows stale/wrong data | [MEDIUM] |
| **LOW** | Cosmetic or test-only: display issues, test failures, doc updates needed | [LOW] |

### Impact Tree Format

Build a tree showing the cascade of impact:

```
IMPACT ANALYSIS: [Description of Change]
=============================================

[CRITICAL] database/models/user.py (line 45)
  - Column 'email_verified' referenced in User model
  - BREAKING: Column removal will cause ORM errors
  |
  +-- [HIGH] services/user_service.py (line 23, 67, 112)
  |     - Uses email_verified in 3 methods
  |     - verify_email(), get_unverified_users(), user_stats()
  |     |
  |     +-- [HIGH] api/routes/users.py (line 34)
  |     |     - POST /api/users/verify-email calls verify_email()
  |     |     |
  |     |     +-- [MEDIUM] frontend/src/pages/VerifyEmail.tsx
  |     |     |     - Calls POST /api/users/verify-email
  |     |     |     - Page will show error on submit
  |     |     |
  |     |     +-- [LOW] frontend/src/components/EmailBanner.tsx
  |     |           - Reads email_verified from user profile API
  |     |           - Banner will show incorrect state
  |     |
  |     +-- [MEDIUM] api/routes/admin.py (line 89)
  |           - GET /api/admin/unverified-users calls get_unverified_users()
  |
  +-- [MEDIUM] services/email_service.py (line 15)
  |     - Checks email_verified before sending marketing emails
  |
  +-- [LOW] tests/test_user_service.py (lines 45, 78, 103)
        - 3 tests reference email_verified
        - Tests will fail

SUMMARY:
  Critical: 1 file
  High:     2 files
  Medium:   3 files
  Low:      2 files
  Total:    8 files affected
```

---

## Step 3: Generate Impact Report

Present a structured impact report:

```markdown
# Impact Analysis Report

## Change Description
[What is being changed and why]

## Blast Radius Summary

| Severity | Count | Files |
|----------|-------|-------|
| CRITICAL | X | [list] |
| HIGH | X | [list] |
| MEDIUM | X | [list] |
| LOW | X | [list] |

## Detailed Impact Tree
[The tree from Step 2]

## Data Migration Required
- [ ] Yes / No
- Migration type: [additive / destructive / transformative]
- Data at risk: [description]
- Estimated rows affected: [count]
- Rollback strategy: [description]

## Breaking Changes
- [ ] API contract changes (affects external consumers)
- [ ] Database schema changes (requires migration)
- [ ] Configuration changes (requires env var updates)
- [ ] Dependency changes (requires package updates)

## Risk Assessment
- **Risk Level**: [Critical / High / Medium / Low]
- **Downtime Required**: [Yes (estimated duration) / No]
- **Rollback Complexity**: [Simple / Medium / Complex]
- **Customer Impact**: [None / Low / Medium / High]
```

---

## Step 4: Generate Migration Plan

Based on the impact analysis, generate an ordered migration plan:

### For Schema Changes

```markdown
# Migration Plan: [Change Description]

## Pre-Migration Checks
1. [ ] Verify current schema state matches expectations
2. [ ] Back up affected tables
3. [ ] Verify no active transactions on affected tables
4. [ ] Notify dependent team(s) if any

## Migration Steps (execute in order)

### Phase 1: Backward-Compatible Changes
1. [ ] Add new column/table (if additive change)
2. [ ] Deploy code that writes to BOTH old and new schema
3. [ ] Backfill new column from old data
4. [ ] Verify data integrity

### Phase 2: Code Migration
5. [ ] Update ORM models
6. [ ] Update repository/DAO layer
7. [ ] Update service layer
8. [ ] Update API response schemas
9. [ ] Update frontend components
10. [ ] Update tests

### Phase 3: Cleanup
11. [ ] Remove old column/table reads from code
12. [ ] Remove old column/table writes from code
13. [ ] Deploy cleanup code
14. [ ] Drop old column/table (after grace period)

## Rollback Plan
1. [ ] Revert code deployment
2. [ ] Run rollback migration: `alembic downgrade -1`
3. [ ] Verify data integrity after rollback

## Estimated Timeline
- Phase 1: [X hours/days]
- Phase 2: [X hours/days]
- Phase 3: [X hours/days] (can wait)
```

### For API Changes (Versioning Strategy)

```markdown
# API Migration Plan

## Strategy: Parallel Version Support

### Phase 1: Introduce New Version
1. [ ] Create v2 endpoint alongside v1
2. [ ] Add deprecation header to v1: `Deprecation: true`
3. [ ] Add `Sunset` header with removal date
4. [ ] Update API documentation

### Phase 2: Consumer Migration
5. [ ] Notify all API consumers of deprecation
6. [ ] Update internal frontend to use v2
7. [ ] Update mobile app to use v2
8. [ ] Monitor v1 usage metrics

### Phase 3: Sunset v1
9. [ ] Return 410 Gone for v1 (after sunset date)
10. [ ] Remove v1 code after grace period
```

### For Feature Removal

```markdown
# Feature Removal Plan

## Phase 1: Deprecation Notice
1. [ ] Add deprecation banner in UI
2. [ ] Send notification to affected users
3. [ ] Add deprecation warnings in API responses
4. [ ] Set sunset date (minimum 30 days)

## Phase 2: Functional Removal
5. [ ] Remove UI navigation links
6. [ ] Disable feature flag (if feature-flagged)
7. [ ] Remove API endpoints (return 410 Gone)
8. [ ] Remove background jobs/cron tasks

## Phase 3: Code Cleanup
9. [ ] Remove frontend components
10. [ ] Remove backend services
11. [ ] Remove database tables (after data export)
12. [ ] Remove test files
13. [ ] Remove configuration entries
14. [ ] Update documentation

## Data Handling
- [ ] Export user data before deletion (GDPR)
- [ ] Archive to cold storage (if required)
- [ ] Purge after retention period
```

---

## Step 5: Validate the Plan

After generating the migration plan, validate:

```bash
# Verify no hidden references remain
grep -rn "AFFECTED_ENTITY" --include="*.py" --include="*.ts" --include="*.java" --include="*.tsx" --include="*.jsx" . | grep -v node_modules | grep -v __pycache__ | grep -v ".git"

# Verify test coverage for affected code
pytest --collect-only 2>/dev/null | grep -i "AFFECTED_ENTITY"
npx jest --listTests 2>/dev/null | grep -i "AFFECTED_ENTITY"

# Verify no orphaned database references
grep -rn "AFFECTED_TABLE\|AFFECTED_COLUMN" --include="*.sql" --include="*.py" --include="*.ts" . | grep -v migration | grep -v alembic
```

---

## Step 6: Output Summary

```
+================================================================+
|  IMPACT ANALYSIS COMPLETE                                       |
+================================================================+
|                                                                 |
|  Change: [description]                                          |
|  Type: [Schema / API / Feature Removal / Refactor / Dep Update] |
|                                                                 |
|  Blast Radius:                                                  |
|  +-- CRITICAL: [X] files                                        |
|  +-- HIGH:     [X] files                                        |
|  +-- MEDIUM:   [X] files                                        |
|  +-- LOW:      [X] files                                        |
|                                                                 |
|  Risk Level: [Critical / High / Medium / Low]                   |
|  Downtime: [Yes/No]                                             |
|  Migration Phases: [X phases, estimated Y days]                 |
|                                                                 |
|  Next Steps:                                                    |
|  1. [First action]                                              |
|  2. [Second action]                                             |
|  3. [Third action]                                              |
+================================================================+
```

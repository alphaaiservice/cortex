---
description: "Trace the impact of a code change across the full stack. Maps database to API to frontend blast radius. Usage: /trace-impact \"rename users.email to users.email_address\""
---

# Trace Impact — Full-Stack Change Impact Analysis

Analyze the impact of: **$ARGUMENTS**

Trace how a proposed code change ripples across the entire stack — from database schema through backend services to frontend components. Works for ANY stack.

**KEY PRINCIPLE: Find EVERY affected file before making changes. A missed reference is a production bug waiting to happen.**

---

## Step 1: Parse the Change Description

Interpret what the user wants to change. Common change types:

```
Change Type Detection:
  Column rename     → "rename X.column to Y.column"
  Table rename      → "rename table X to Y"
  Field add/remove  → "add/remove field X from Y"
  API change        → "change endpoint /api/X to /api/Y"
  Type change       → "change X from string to integer"
  Logic change      → "move X logic from A to B"
  Dependency swap   → "replace library X with Y"
  Config change     → "change X setting from A to B"
  Feature removal   → "remove feature X"
  Service split     → "extract X into separate service"
```

Parse out:
- **Entity**: What is being changed (table, column, endpoint, function, class)
- **Operation**: What kind of change (rename, add, remove, modify, move)
- **Old value**: Current name/value
- **New value**: Target name/value (if applicable)

---

## Step 2: Find All Code References

### 2.1: Direct References (Exact Match)

```bash
# Search for exact string matches across all code files
grep -rn "[old_value]" . --include="*.py" --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" --include="*.java" --include="*.go" --include="*.rb" --include="*.rs" --include="*.sql" --include="*.graphql" --include="*.prisma" --include="*.yaml" --include="*.yml" --include="*.json" --include="*.toml" --include="*.env*" --include="*.md" -l

# Search for common variations (camelCase, snake_case, PascalCase, kebab-case)
# e.g., for "email_address": emailAddress, EmailAddress, email-address
grep -rn "[camelCase_variant]" . --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" -l
grep -rn "[PascalCase_variant]" . --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" -l
```

### 2.2: Schema & Model References

```
Scan for:
  SQL migrations     → migrations/, alembic/, knex/, prisma/migrations/
  ORM models         → models/, entities/, schemas/
  Prisma schema      → schema.prisma
  GraphQL schema     → *.graphql, *.gql
  API schemas        → schemas/, dto/, serializers/, validators/
  Type definitions   → types/, interfaces/, *.d.ts
  Proto definitions  → *.proto
```

### 2.3: Service & Repository Layer

```
Scan for:
  Repositories       → repositories/, repos/, dal/
  Services           → services/, use-cases/, business/
  Controllers        → controllers/, routes/, handlers/, views/
  Middleware          → middleware/, interceptors/, guards/
  Utils/Helpers      → utils/, helpers/, lib/
```

### 2.4: API Layer

```
Scan for:
  Route definitions  → routes/, api/, endpoints/
  API documentation  → swagger, openapi, *.yaml API specs
  Request/Response   → dto/, request/, response/
  API tests          → test*api*, *integration*, *e2e*
  Postman/Insomnia   → *.postman_collection.json, *.insomnia*
```

### 2.5: Frontend References

```
Scan for:
  API calls          → fetch, axios, useSWR, useQuery, $http
  Type definitions   → types/, interfaces/, api.ts
  Form fields        → name="[field]", register("[field]")
  Display components → {data.[field]}, {{[field]}}, v-model="[field]"
  Validation schemas → zod, yup, joi schemas referencing the field
  State management   → store/, slices/, atoms/, signals/
  URL parameters     → router params, query strings, path segments
```

### 2.6: Configuration & Infrastructure

```
Scan for:
  Environment vars   → .env*, docker-compose.yml, k8s manifests
  CI/CD pipelines    → .github/workflows/, .gitlab-ci.yml, Jenkinsfile
  Database seeds     → seeds/, fixtures/, factories/
  Documentation      → docs/, README*, CHANGELOG*, API docs
```

---

## Step 3: Map the Dependency Chain

Build a layered dependency map showing how the change propagates:

```
DEPENDENCY CHAIN
════════════════

Layer 1: DATABASE / SCHEMA
  └─ [migration file] — [what changes]
  └─ [seed/fixture file] — [what changes]

Layer 2: ORM / MODELS
  └─ [model file] — [field/relation affected]
  └─ [type definition] — [interface/type affected]

Layer 3: REPOSITORY / DATA ACCESS
  └─ [repo file] — [queries affected]

Layer 4: SERVICE / BUSINESS LOGIC
  └─ [service file] — [methods affected]
  └─ [validation] — [rules affected]

Layer 5: API / CONTROLLERS
  └─ [controller file] — [endpoints affected]
  └─ [middleware] — [if auth/permissions affected]
  └─ [API docs] — [spec changes needed]

Layer 6: FRONTEND / CLIENT
  └─ [API client] — [request/response types]
  └─ [components] — [display/form fields]
  └─ [pages] — [data fetching affected]
  └─ [state management] — [store/slice changes]

Layer 7: TESTS
  └─ [unit tests] — [test cases to update]
  └─ [integration tests] — [API tests to update]
  └─ [e2e tests] — [flows to update]

Layer 8: CONFIGURATION / INFRA
  └─ [env files] — [if config key changes]
  └─ [CI/CD] — [if pipeline references it]
  └─ [docs] — [documentation to update]
```

---

## Step 4: Calculate Blast Radius

### 4.1: Quantify the Impact

```
BLAST RADIUS SUMMARY
════════════════════
Total files affected:     [count]
Total lines to change:    [approximate count]
Layers affected:          [count] of 8

Breakdown by layer:
  Database/Schema:        [count] files
  Models/Types:           [count] files
  Repository/DAL:         [count] files
  Services/Logic:         [count] files
  API/Controllers:        [count] files
  Frontend/Client:        [count] files
  Tests:                  [count] files
  Config/Infra:           [count] files
```

### 4.2: Assess Risk Level

```
Risk Assessment Rules:
  CRITICAL  — Change touches authentication, authorization, payments, or encryption
  HIGH      — Change touches API contracts (breaking change for consumers)
  HIGH      — Change requires database migration on production data
  MEDIUM    — Change touches multiple services/modules
  MEDIUM    — Change affects shared types or interfaces
  LOW       — Change is isolated to frontend display
  LOW       — Change only affects tests or documentation
```

### 4.3: Identify Breaking Changes

```
Breaking Change Detection:
  API Response shape changed?     → External consumers affected
  Database column renamed/removed? → Running queries will fail
  Environment variable renamed?    → Deployment config must update
  Import path changed?             → All importers must update
  Function signature changed?      → All callers must update
  Event name changed?              → All listeners must update
```

---

## Step 5: Generate Migration Plan

Create an ordered, step-by-step migration plan:

```markdown
## Migration Plan

### Phase 1: Preparation (No downtime)
1. [ ] Create database migration (ADD new column, keep old)
2. [ ] Update ORM model to support both old and new
3. [ ] Add backward-compatible API support

### Phase 2: Code Migration (Deploy together)
4. [ ] Update repository layer queries
5. [ ] Update service layer logic
6. [ ] Update API controllers and DTOs
7. [ ] Update frontend API client types
8. [ ] Update frontend components
9. [ ] Update all test files

### Phase 3: Cleanup (After verification)
10. [ ] Remove backward compatibility code
11. [ ] Drop old database column (migration)
12. [ ] Update documentation
13. [ ] Update API specs
14. [ ] Notify API consumers (if external)

### Rollback Plan
- If Phase 1: Simply drop the new migration
- If Phase 2: Revert code deploy, old column still works
- If Phase 3: Cannot easily rollback — verify thoroughly before this phase
```

---

## Step 6: Generate Impact Report

Save as impact report or display inline:

```markdown
# Impact Analysis Report
**Change**: [description]
**Generated**: [date]
**Risk Level**: CRITICAL | HIGH | MEDIUM | LOW

## Change Summary
| Attribute | Value |
|-----------|-------|
| Entity | [what is changing] |
| Operation | [rename/add/remove/modify] |
| Old Value | [current] |
| New Value | [target] |

## Blast Radius
| Layer | Files | Risk | Details |
|-------|-------|------|---------|
| Database | [n] | [risk] | [summary] |
| Models | [n] | [risk] | [summary] |
| Repository | [n] | [risk] | [summary] |
| Services | [n] | [risk] | [summary] |
| API | [n] | [risk] | [summary] |
| Frontend | [n] | [risk] | [summary] |
| Tests | [n] | [risk] | [summary] |
| Config | [n] | [risk] | [summary] |
| **Total** | **[N]** | **[overall]** | |

## Affected Files (Complete List)
### Must Change (code will break without these)
| # | File | Layer | Change Required |
|---|------|-------|----------------|
| 1 | [file path] | [layer] | [what to change] |

### Should Change (will work but inconsistent without these)
| # | File | Layer | Change Required |
|---|------|-------|----------------|

### May Need Change (verify manually)
| # | File | Layer | Reason to Check |
|---|------|-------|-----------------|

## Breaking Changes
| Change | Severity | Affected Consumers |
|--------|----------|-------------------|
| [description] | [severity] | [who is affected] |

## Migration Plan
[Ordered steps from Step 5]

## Estimated Effort
| Phase | Tasks | Time |
|-------|-------|------|
| Preparation | [n] tasks | [estimate] |
| Code Migration | [n] tasks | [estimate] |
| Cleanup | [n] tasks | [estimate] |
| Testing | [n] tasks | [estimate] |
| **Total** | **[N]** | **[total]** |

## Risks & Mitigations
| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| [risk] | [H/M/L] | [H/M/L] | [strategy] |
```

---

## Step 7: Output Summary

```
╔══════════════════════════════════════════════════════════════╗
║  IMPACT ANALYSIS COMPLETE                                     ║
╠══════════════════════════════════════════════════════════════╣
║  Change: [brief description]                                  ║
║  Risk Level: [CRITICAL/HIGH/MEDIUM/LOW]                       ║
║                                                               ║
║  Blast Radius:                                                ║
║    Files affected:    [N] files across [M] layers             ║
║    Breaking changes:  [count]                                 ║
║    Tests to update:   [count]                                 ║
║                                                               ║
║  Migration: [N] steps across [M] phases                       ║
║  Estimated effort: [time estimate]                            ║
║                                                               ║
║  Highest risk: [most dangerous aspect of this change]         ║
╚══════════════════════════════════════════════════════════════╝
```

---

## Critical Rules

1. **Find EVERY reference.** A missed file means a runtime error in production. When in doubt, include it in the "May Need Change" list.

2. **Check ALL naming conventions.** A column named `email_address` may appear as `emailAddress` in JavaScript, `EmailAddress` in C#, and `email-address` in URLs. Search for ALL variants.

3. **Consider indirect references.** A column rename affects not just direct queries but also: ORM relations, indexes, database views, stored procedures, cached queries, and serialized data.

4. **Order matters in migration.** Database changes must happen before code changes. Code changes must deploy atomically. Cleanup happens last.

5. **Always include a rollback plan.** Every migration phase should be reversible. If it is not reversible, flag it clearly.

6. **Flag external dependencies.** If the change affects a public API consumed by external clients, mobile apps, or third-party integrations, escalate the risk level.

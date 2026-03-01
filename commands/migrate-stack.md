---
description: "Safely migrate technology components in an existing app to Alpha AI's standard stack. Handles data migration, code refactoring, and testing. Usage: /migrate-stack <migration-description>"
---

# Stack Migration — Safe Technology Replacement

Migrate: **$ARGUMENTS**

This command safely migrates technology components in an existing application to Alpha AI's standard stack, with zero data loss and minimal downtime.

---

## Supported Migrations

### Database Migrations
| From | To | Complexity | Data Migration |
|------|----|-----------|----------------|
| PostgreSQL | MySQL 8.0 + SQLAlchemy async | 🔴 Large | Yes — full schema + data |
| SQLite | MySQL 8.0 + SQLAlchemy async | 🟡 Medium | Yes — full schema + data |
| Prisma (PostgreSQL) | SQLAlchemy 2.0 async + asyncmy | 🔴 Large | Yes — schema translation + data |
| TypeORM | SQLAlchemy 2.0 async | 🔴 Large | Yes — schema translation |
| Mongoose/Motor/Beanie | PyMongo (sync) | 🟡 Medium | No data move — same MongoDB |
| Memcached | Redis (redis.asyncio) | 🟢 Small | No — cache is ephemeral |
| Firebase Firestore | MongoDB + PyMongo | 🔴 Large | Yes — export/import |

### Auth Migrations
| From | To | Complexity |
|------|----|-----------|
| localStorage JWT | HTTP-Only Cookie JWT | 🟡 Medium |
| sessionStorage JWT | HTTP-Only Cookie JWT | 🟡 Medium |
| Bearer header (frontend) | Cookie-based auth | 🟡 Medium |
| Firebase Auth | Custom JWT + HTTP-Only Cookies | 🔴 Large |
| Auth0 / Clerk | Custom JWT + HTTP-Only Cookies | 🔴 Large |
| Session-based auth | JWT + HTTP-Only Cookies | 🟡 Medium |
| Google JS SDK popup | authlib server-side OAuth | 🟡 Medium |

### Payment Migrations
| From | To | Complexity |
|------|----|-----------|
| Stripe | Razorpay (Subscriptions + Credit Points) | 🔴 Large |
| PayPal | Razorpay | 🔴 Large |
| No payments | Razorpay + Credit Points | 🟡 Medium |

### Framework Migrations
| From | To | Complexity |
|------|----|-----------|
| Flask | FastAPI (async) | 🔴 Large |
| Django | FastAPI (async) | ⚫ XL |
| Express.js | FastAPI (Python rewrite) | ⚫ XL |
| React (CRA/Vite) | Next.js 15+ (App Router) | 🔴 Large |
| Vue.js | Next.js 15+ | ⚫ XL |
| Flutter | React Native + Expo SDK 55+ | ⚫ XL |

### Linter/Tooling Migrations
| From | To | Complexity |
|------|----|-----------|
| flake8 + black + isort | ruff | 🟢 Small |
| pylint | ruff | 🟢 Small |
| ESLint (no types) | TypeScript strict | 🟡 Medium |
| unittest | pytest + pytest-asyncio | 🟡 Medium |

### GenAI Migrations
| From | To | Complexity |
|------|----|-----------|
| Direct OpenAI SDK | LiteLLM gateway | 🟡 Medium |
| Direct Anthropic SDK | LiteLLM gateway | 🟡 Medium |
| LangChain | Google ADK / LangGraph | 🔴 Large |
| Pinecone | Qdrant (self-hosted) | 🟡 Medium |
| Chroma | Qdrant | 🟡 Medium |
| Hardcoded prompts | Jinja2/YAML template files | 🟡 Medium |

---

## Step 1: Analyze Current Implementation

For the requested migration, deeply understand what exists:

```
Use Glob + Grep to find ALL files that reference the "from" technology:

1. Dependencies — where it's imported/required
2. Configuration — connection strings, API keys, settings
3. Code — all usage points (models, queries, API calls)
4. Tests — tests that depend on the old technology
5. Docker — docker-compose services
6. CI/CD — pipeline references
7. Documentation — README, CLAUDE.md references
```

Generate a **migration impact map**:
- Total files affected: [count]
- Total lines to change: [estimate]
- External dependencies: [list]
- Data at risk: [yes/no, what data]

---

## Step 2: Create Migration Plan

```markdown
# Migration Plan: [from] → [to]

## Phase 1: Preparation
- [ ] Backup existing database/data
- [ ] Create migration branch
- [ ] Add new dependencies alongside old ones
- [ ] Create compatibility layer (if needed)

## Phase 2: Schema/Model Migration
- [ ] Create new models/schemas matching old ones
- [ ] Write data migration scripts
- [ ] Test migration on copy of production data

## Phase 3: Code Migration
- [ ] Update all [count] files that reference old technology
- [ ] Update configuration/environment variables
- [ ] Update Docker services
- [ ] Maintain backward compatibility during transition

## Phase 4: Data Migration (if applicable)
- [ ] Export data from old system
- [ ] Transform data format
- [ ] Import into new system
- [ ] Verify data integrity (row counts, checksums)

## Phase 5: Testing
- [ ] Update all affected tests
- [ ] Run full test suite
- [ ] Manual smoke test

## Phase 6: Cleanup
- [ ] Remove old dependencies
- [ ] Remove old configuration
- [ ] Remove compatibility layer
- [ ] Update documentation

## Rollback Plan
- [How to revert if migration fails]
- [Backup locations]
- [Estimated rollback time]
```

**Present plan to user** and ask for confirmation before proceeding.

---

## Step 3: Execute Migration

### General Migration Rules:

1. **ALWAYS backup first** — Before any destructive changes
2. **Work in a branch** — `git checkout -b migrate/[from]-to-[to]`
3. **Parallel install** — Add new deps alongside old ones (don't remove old yet)
4. **Incremental migration** — Migrate one module at a time, test after each
5. **Adapter pattern** — If needed, create an adapter that works with both old and new
6. **Run tests after every file change** — Catch regressions immediately
7. **NEVER lose data** — If data migration is involved, verify counts and checksums
8. **Keep old code commented** (temporarily) until migration verified

### Database-Specific Rules:

**PostgreSQL → MySQL:**
```
1. Map PostgreSQL types to MySQL equivalents:
   - SERIAL → INT AUTO_INCREMENT
   - TEXT → LONGTEXT
   - BOOLEAN → TINYINT(1)
   - JSON/JSONB → JSON
   - UUID → CHAR(36) or BINARY(16)
   - TIMESTAMP WITH TZ → DATETIME(6)
   - ARRAY → JSON (or separate table)
   - ENUM → ENUM

2. Handle PostgreSQL-specific features:
   - ILIKE → LOWER() + LIKE
   - Array contains → JSON_CONTAINS()
   - Full-text search → Meilisearch (don't use MySQL FULLTEXT)
   - CTE (WITH) → Supported in MySQL 8.0+

3. Update SQLAlchemy models:
   - Change dialect from postgresql+asyncpg to mysql+asyncmy
   - Update column types
   - Handle auto-increment differences

4. Data migration:
   - pg_dump → transform → mysql import
   - OR: write Python script to read from PG, write to MySQL
```

**localStorage → HTTP-Only Cookies:**
```
1. Backend changes:
   - Add set_cookie() on login/refresh endpoints
   - Add cookie reading in auth dependency
   - Add CSRF double-submit cookie
   - Add cookie clearing on logout

2. Frontend changes:
   - Remove all localStorage.setItem('token') calls
   - Remove all localStorage.getItem('token') calls
   - Remove Authorization header from API client
   - Add withCredentials: true to Axios
   - Add CSRF token to POST/PUT/DELETE requests
   - Change auth state from localStorage to /auth/me endpoint

3. Token refresh:
   - Remove manual token refresh logic
   - Add 401 interceptor that calls /auth/refresh
```

**Stripe → Razorpay:**
```
1. Create new Razorpay models (Subscription, CreditBalance, PointTransaction, TopupOrder)
2. Create Razorpay client config (replace Stripe SDK)
3. Migrate subscription flow:
   - Stripe Checkout → Razorpay Checkout
   - Stripe Webhooks → Razorpay Webhooks
   - Stripe Customer → Razorpay Customer
4. Add credit point system (Stripe doesn't have this)
5. Add GST 18% to invoices (India requirement)
6. Add top-up packs (new feature with Razorpay Orders)
7. Migrate existing subscriber data:
   - Map Stripe subscription IDs to Razorpay
   - Create initial point balances
8. ⚠️ CRITICAL: Run both payment systems in parallel during transition
```

**Direct OpenAI SDK → LiteLLM:**
```
1. Replace imports:
   - from openai import OpenAI → import litellm
   - client.chat.completions.create() → litellm.acompletion()
   - client.embeddings.create() → litellm.aembedding()

2. Add model registry:
   - Map current model names to LiteLLM format
   - Add fallback chains

3. Add cost tracking:
   - Wrap all LiteLLM calls with cost calculation
   - Integrate with credit point system (if exists)
```

---

## Step 4: Verify Migration

```bash
# 1. Run linter
ruff check app/ 2>/dev/null || npx tsc --noEmit 2>/dev/null

# 2. Run ALL tests
pytest 2>/dev/null || npm test 2>/dev/null

# 3. Data integrity check (if data migration)
echo "Old system record count vs new system record count"

# 4. Smoke test
python -c "from app.main import app; print('✅ App loads')" 2>/dev/null
```

---

## Step 5: Cleanup

After migration is verified:

1. **Remove old dependencies** from requirements.txt / package.json
2. **Remove old config** from .env.example
3. **Remove old Docker services** from docker-compose.yml
4. **Remove commented-out old code**
5. **Update CLAUDE.md** with new stack
6. **Update documentation**

---

## Step 6: Output Summary

```
╔══════════════════════════════════════════════════════════════╗
║  MIGRATION COMPLETE: [from] → [to]                            ║
╠══════════════════════════════════════════════════════════════╣
║                                                               ║
║  Files Modified: [count]                                      ║
║  Files Created: [count]                                       ║
║  Files Removed: [count]                                       ║
║                                                               ║
║  Dependencies Added: [list]                                   ║
║  Dependencies Removed: [list]                                 ║
║                                                               ║
║  Data Migration: [yes/no]                                     ║
║  Records Migrated: [count]                                    ║
║  Data Integrity: ✅ Verified                                  ║
║                                                               ║
║  Tests: [X] passing, [Y] updated, [Z] new                   ║
║                                                               ║
║  ⚠️ Manual Steps:                                             ║
║  1. [Update production env vars]                              ║
║  2. [Run migration on production DB]                          ║
║  3. [Update CI/CD secrets]                                    ║
╚══════════════════════════════════════════════════════════════╝
```

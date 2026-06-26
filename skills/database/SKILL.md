---
name: database
description: "Auto-invoked when writing data-model code or schema changes — ORM models/entities, migrations (Alembic/Prisma migrate/Flyway), repository queries, indexes, or choosing MySQL vs MongoDB vs Redis. Enforces Alpha AI data standards: safe reversible zero-downtime migrations, correct datastore selection, indexing, and the repository layer boundary. Complements the performance skill (query tuning) with schema + migration safety."
---

# Database & Data-Modeling Standards

This skill enforces Alpha AI's data standards on every schema change, migration, and model edit. It owns **datastore selection + schema/migration safety + the repository boundary**; the `performance` skill owns **query tuning + indexing depth**. They fire together on data code.

Per-language specifics live in `alpha-architecture/references/` — load on demand:
- **`CODE_PATTERNS_PYTHON.md`** — SQLAlchemy 2.0 async + Alembic
- **`CODE_PATTERNS_NESTJS.md`** — Prisma + prisma migrate
- **`CODE_PATTERNS_SPRINGBOOT.md`** — Spring Data JPA + Flyway

---

## Hard Rules

### 1. Pick the right datastore
- **MySQL + ORM** — relational, transactional, source-of-truth data (users, orders, billing). Default.
- **MongoDB** — flexible/denormalized documents, high-write event-ish data, schemas that vary per record.
- **Redis** — cache, sessions, rate limits, queues, pub/sub, token blacklist. NEVER the source of truth.
- ❌ NEVER store JWT/session source-of-truth or money in Redis; NEVER force document data into rigid SQL just to avoid Mongo.

### 2. Layer boundary (with `alpha-architecture`)
- ✅ ALL queries live in the **repository layer** — `app/repositories/` · NestJS Prisma access · `**/repository/`.
- ❌ Services NEVER write raw queries; controllers NEVER touch the DB. Business logic stays out of repositories.

### 3. Migrations — safe, reversible, zero-downtime
- ✅ EVERY schema change ships as a versioned migration (Alembic / Prisma migrate / Flyway) — never hand-edited DBs.
- ✅ Every migration has a tested **down/rollback** path.
- ✅ **Expand → migrate → contract** for breaking changes: add new column nullable → backfill → switch reads/writes → drop old. Never rename/drop in one shot on a live table.
- ✅ Backfills run in **batches** (not one giant `UPDATE`); avoid long locks on large tables.
- ❌ NEVER add a `NOT NULL` column without a default or backfill; NEVER drop a column still read by deployed code.
- ✅ Wrap multi-step DDL in transactions where the engine supports it; gate destructive migrations behind a backup (`/backup-dr`).

### 4. Schema design
- ✅ Explicit types, lengths, `NOT NULL` where appropriate, foreign keys with intentional `ON DELETE` behavior.
- ✅ Indexes on FKs, WHERE/ORDER BY/JOIN columns; composite indexes follow leftmost-prefix (see `performance`).
- ✅ `created_at` / `updated_at` timestamps; soft-delete where audit matters.
- ✅ Money as integer minor units (or `DECIMAL`) — NEVER float. UTC timestamps only.
- ❌ NEVER `SELECT *` in repositories — project explicit columns.

### 5. Integrity & safety
- ✅ Enforce constraints at the DB (unique, FK, check) — not only in app code.
- ✅ Use transactions for multi-write operations; pick the right isolation level.
- ✅ Parameterized queries / ORM only — NEVER string-concatenate SQL (see `security`).
- ✅ Seed/test data via factories (`/seed-data`), never ad-hoc inserts in app startup.

---

## Verify
- Run the migration up AND down on a scratch DB before merging.
- Check `EXPLAIN` on new/changed hot queries (see `performance`).
- Confirm no deployed code reads a column the migration removes (use `/trace-impact`).

## How this skill works with others
- `performance` — query/index tuning depth; this skill owns schema + migration safety.
- `alpha-architecture` — repository layer boundary + per-language ORM stack.
- `security` — injection-safe queries, least-privilege DB users, secrets for credentials.
- `/db-migrate`, `/backup-dr`, `db-optimizer` agent — the command/agent surface this skill keeps compliant.

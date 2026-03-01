---
description: "Generate and manage database migrations safely. Usage: /db-migrate <action> (generate|run|rollback|status)"
---

# Database Migration Helper

Action: **$ARGUMENTS**

## Detect Database Setup

1. Identify ORM/migration tool:
   - Prisma, Drizzle, TypeORM, Sequelize (Node.js)
   - Alembic, Django migrations (Python)
   - GORM, golang-migrate (Go)
   - Raw SQL migrations

2. Identify database type from connection strings / config

## Actions

### `generate` — Generate a new migration
1. Analyze model/schema changes vs current database state
2. Generate migration file with:
   - Descriptive name based on changes
   - UP migration (apply changes)
   - DOWN migration (rollback changes)
   - Data migration if needed (not just schema)
3. Review the generated migration for safety:
   - No data loss operations without explicit confirmation
   - Proper index creation for new columns
   - Foreign key constraints
   - Default values for new NOT NULL columns

### `run` — Apply pending migrations
1. Show pending migrations
2. **Ask for confirmation**
3. Apply migrations
4. Verify database state

### `rollback` — Rollback last migration
1. Show what will be rolled back
2. **Ask for confirmation**
3. Execute rollback
4. Verify database state

### `status` — Show migration status
1. List all migrations (applied and pending)
2. Show current database schema version
3. Flag any drift between models and database

## Safety Rules
- NEVER drop tables or columns without explicit user confirmation
- ALWAYS generate DOWN migrations
- ALWAYS backup recommendation before destructive operations
- Validate migration in a test/dry-run mode if possible

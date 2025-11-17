# Scenario 08: Brownfield Migration

## Objective
Adopt DBLift for an existing database that wasn't created with migrations.

## Prerequisites
- DBLift installed
- Existing database with schema already in place
- No previous migration history

## Problem Statement

You have an existing production database with:
- Established schema
- Live data
- No migration history
- Manual schema evolution

**Goal**: Start using DBLift without breaking existing systems.

## Steps

### 1. Analyze Existing Schema

First, inspect your current database schema:

```bash
# Connect to database
docker exec -it dblift-demo-postgres psql -U dblift_user -d dblift_demo

# List tables
\dt

# Show table structure
\d users
\d customers
\d products

\q
```

### 2. Export Current Schema

Generate DDL for existing schema:

```bash
docker exec -it dblift-demo-postgres pg_dump \
  -U dblift_user \
  -d dblift_demo \
  --schema-only \
  --no-owner \
  --no-privileges \
  > current-schema.sql
```

Review the exported schema to understand what exists.

### 3. Create Baseline Migration

Option A: **Manual baseline** - Create initial migration matching current schema:

```bash
mkdir -p migrations/brownfield
cp current-schema.sql migrations/brownfield/V1_0_0__Baseline_existing_schema.sql
```

Edit the file to clean up and organize.

Option B: **Incremental baseline** - Break down into logical migrations:

```sql
-- migrations/brownfield/V1_0_0__Baseline_users.sql
CREATE TABLE users (
    -- existing schema
);

-- migrations/brownfield/V1_0_1__Baseline_products.sql
CREATE TABLE products (
    -- existing schema
);
```

### 4. Baseline the Database

Mark existing schema as already applied without running migrations:

```bash
dblift baseline \
  --config config/dblift-postgresql.yaml \
  --baseline-version 1.0.0 \
  --baseline-description "Initial baseline of existing production database"
```

**What this does:**
- Creates dblift_schema_history table
- Marks migrations up to 1.0.0 as applied
- Does NOT execute any SQL
- Database remains unchanged

### 5. Verify Baseline

```bash
dblift info --config config/dblift-postgresql.yaml
```

Output:
```
Database: jdbc:postgresql://localhost:5432/dblift_demo
Schema: public

Applied migrations:
  V1.0.0 - Baseline existing schema (baselined)

Pending migrations: 0

Status: Up to date (baselined)
```

### 6. Add New Migration

Now you can add new migrations:

```sql
-- migrations/V1_0_1__Add_api_keys_table.sql
CREATE TABLE api_keys (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id),
    key_hash VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by VARCHAR(50) DEFAULT 'system' NOT NULL
);
```

### 7. Apply New Migrations

```bash
dblift migrate --config config/dblift-postgresql.yaml
```

Only new migrations (after baseline) will be applied.

### 8. Handle Schema Drift

If the current schema doesn't match your baseline migration:

```bash
dblift diff \
  --config config/dblift-postgresql.yaml \
  --generate-migration \
  --output migrations/V1_0_0_1__Fix_baseline_drift.sql
```

This generates a migration to align schema with expectations.

## Advanced Brownfield Scenarios

### Scenario A: Partial Adoption

Start managing only new tables:

```bash
# Don't baseline everything
# Just add new migrations for new tables

dblift migrate \
  --config config/dblift-postgresql.yaml \
  --ignore-unmanaged
```

Existing tables are ignored, new tables are managed.

### Scenario B: Progressive Adoption

Gradually bring tables under management:

```sql
-- Week 1: Baseline users
V1_0_0__Baseline_users_table.sql

-- Week 2: Baseline products
V1_0_1__Baseline_products_table.sql

-- Week 3: Baseline orders
V1_0_2__Baseline_orders_table.sql
```

Use `--ignore-unmanaged` until all tables are baselined.

### Scenario C: Multi-Environment Brownfield

Different environments have different schemas:

```bash
# Production (oldest)
dblift baseline \
  --config config-prod.yaml \
  --baseline-version 1.0.0

# Staging (newer)
dblift baseline \
  --config config-staging.yaml \
  --baseline-version 1.2.0

# Dev (newest)
dblift baseline \
  --config config-dev.yaml \
  --baseline-version 1.5.0
```

Then bring environments into alignment with migrations.

### Scenario D: Import from Another Tool

If migrating from Flyway/Liquibase:

```bash
# Export Flyway history
# Convert to DBLift format

dblift import-history \
  --source flyway \
  --history-table flyway_schema_history \
  --config config/dblift-postgresql.yaml
```

## Best Practices

### 1. Backup First
```bash
# Always backup before baselining
pg_dump -U user -d database > backup-$(date +%Y%m%d).sql
```

### 2. Test in Non-Production First
```bash
# Baseline dev/staging first
dblift baseline --config config-dev.yaml

# Verify everything works

# Then production
dblift baseline --config config-prod.yaml
```

### 3. Document Baseline
Create `migrations/BASELINE_NOTES.md`:
```markdown
# Baseline Information

- Date: 2024-02-20
- Database version: PostgreSQL 15
- Schema dump: current-schema.sql
- Baseline version: 1.0.0

## What was included:
- All core tables
- All indexes
- All foreign keys

## What was excluded:
- Legacy temp tables
- BI views (created by external tool)
```

### 4. Handle Drift Carefully
```bash
# Check drift after baseline
dblift diff --config config.yaml

# If drift exists, decide:
# A) Update baseline migration to match
# B) Create drift-fix migration
# C) Mark as intentional with --ignore-unmanaged
```

### 5. Version Strategy

Choose appropriate baseline version:
- `1.0.0` - Clean start
- `2.0.0` - Major version if significant
- Match existing versioning if you have one

## Common Issues

### Issue: "Table already exists"
**Cause**: Baseline wasn't applied before migration.
**Solution:**
```bash
dblift baseline --baseline-version 1.0.0
```

### Issue: "Checksum mismatch"
**Cause**: Baseline migration doesn't match actual schema.
**Solution:**
```bash
# Regenerate baseline from current schema
dblift diff --generate-migration --output V1_0_0__Baseline.sql
```

### Issue: "Unknown objects in database"
**Cause**: Schema has tables not in baseline.
**Solution:**
```bash
# Allow unmanaged objects
dblift migrate --ignore-unmanaged

# Or add to baseline
# Or use progressive adoption
```

## Migration Path

```
Existing Database (no history)
  ↓
Export current schema
  ↓
Create baseline migration (V1.0.0)
  ↓
Run: dblift baseline
  ↓
Verify: dblift info
  ↓
Add new migrations (V1.0.1+)
  ↓
Apply: dblift migrate
  ↓
Ongoing migration management
```

## Key Takeaways
- Baseline enables brownfield adoption
- No need to rebuild existing databases
- Can start managing only new changes
- Progressive adoption is supported
- Diff detection helps with accuracy
- Always test in non-production first
- Document the baseline process

## Checklist

- [ ] Backup existing database
- [ ] Export current schema to SQL
- [ ] Create baseline migration file(s)
- [ ] Test baseline in dev/staging
- [ ] Run `dblift baseline` in production
- [ ] Verify with `dblift info`
- [ ] Check for drift with `dblift diff`
- [ ] Document baseline in migration notes
- [ ] Add first new migration
- [ ] Test full migration workflow
- [ ] Update team documentation

## Next Steps
- Try [Scenario 09: Targeted Schema Exports](../10-export-schema/) to see how exports complement baselines.


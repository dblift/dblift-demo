# Scenario 05: Schema Drift Detection

## Objective
Detect manual schema changes outside of migrations.

## Prerequisites
- DBLift installed
- Database running with migrations applied

## Steps

### 1. Apply All Migrations

```bash
dblift migrate --config config/dblift-postgresql.yaml
```

### 2. Check for Drift (Clean State)

```bash
dblift diff --config config/dblift-postgresql.yaml
```

**Expected Output:**
```
✅ No drift detected
Database schema matches applied migrations
```

### 3. Simulate Manual Schema Changes

Run the drift simulation script:
```bash
docker exec -it dblift-demo-postgres psql -U dblift_user -d dblift_demo -f /workspace/scripts/simulate-drift.sql
```

Or manually execute:
```sql
-- Add columns not in migrations
ALTER TABLE users ADD COLUMN phone VARCHAR(20);
ALTER TABLE users ADD COLUMN department VARCHAR(50);

-- Create unmanaged table
CREATE TABLE temp_imports (
    id SERIAL PRIMARY KEY,
    data JSONB,
    imported_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Drop an index
DROP INDEX idx_users_email;

-- Modify a column
ALTER TABLE products ALTER COLUMN is_active SET DEFAULT FALSE;

-- Add unmanaged constraint
ALTER TABLE customers 
ADD CONSTRAINT chk_email_format 
CHECK (contact_email ~ '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}$');
```

### 4. Detect Drift

```bash
dblift diff --config config/dblift-postgresql.yaml
```

**Expected Output:**
```
⚠️  Schema Drift Detected
══════════════════════════════════

Table: users
  ➕ Extra column: phone (VARCHAR(20))
  ➕ Extra column: department (VARCHAR(50))
  ❌ Missing index: idx_users_email

Table: products
  ⚠️  Modified column: is_active (default changed)

Table: customers
  ➕ Extra constraint: chk_email_format

Unmanaged Objects:
  ➕ Table: temp_imports (not defined in migrations)

══════════════════════════════════
Summary:
  Modified tables: 3
  Unmanaged tables: 1
  Missing indexes: 1
  Extra columns: 2
  Extra constraints: 1
```

### 5. Generate Detailed Drift Report

```bash
dblift diff \
  --config config/dblift-postgresql.yaml \
  --log-format html \
  --log-dir reports/
```

Open `reports/dblift_diff_*.html` for interactive report.

### 6. Generate JSON Report for Automation

```bash
dblift diff \
  --config config/dblift-postgresql.yaml \
  --format json \
  --output drift-report.json
```

### 7. Ignore Unmanaged Objects

If you have legacy tables you want to ignore:

```bash
dblift diff \
  --config config/dblift-postgresql.yaml \
  --ignore-unmanaged
```

This will only show drift in managed tables.

### 8. Create Migration from Drift

You can generate a migration to incorporate the drift:

```bash
dblift diff \
  --config config/dblift-postgresql.yaml \
  --generate-migration \
  --output migrations/V1_4_0__Incorporate_manual_changes.sql
```

This creates a migration file with the detected changes.

### 9. Schedule Automated Drift Detection

The repository includes a GitHub Actions workflow for scheduled drift detection. Review it:

```bash
cat .github/workflows/drift-detection.yml
```

This runs daily and creates issues when drift is detected.

## Drift Detection Strategies

### Strategy 1: Zero Tolerance
```yaml
# Fail on any drift
dblift diff --config config.yaml --fail-on-drift
```

### Strategy 2: Allow Unmanaged
```yaml
# Allow unmanaged objects (for brownfield)
dblift diff --config config.yaml --ignore-unmanaged
```

### Strategy 3: Baseline and Monitor
```bash
# Create baseline of current state
dblift baseline --config config.yaml

# Then monitor for new drift
dblift diff --config config.yaml --since-baseline
```

## Fixing Drift

### Option 1: Revert Manual Changes
```sql
-- Undo the manual changes
ALTER TABLE users DROP COLUMN phone;
ALTER TABLE users DROP COLUMN department;
CREATE INDEX idx_users_email ON users(email);
DROP TABLE temp_imports;
ALTER TABLE customers DROP CONSTRAINT chk_email_format;
```

### Option 2: Create Migration
```sql
-- Create V1_4_0__Add_user_contact_info.sql
ALTER TABLE users ADD COLUMN phone VARCHAR(20);
ALTER TABLE users ADD COLUMN department VARCHAR(50);
```

Then apply it:
```bash
dblift migrate --config config/dblift-postgresql.yaml
```

## Key Takeaways
- Drift detection catches manual schema changes
- Identifies unmanaged objects (brownfield support)
- Generates detailed reports (TEXT, JSON, HTML)
- Can be automated in CI/CD
- Helps maintain schema governance
- Supports both strict and permissive modes

## Common Drift Scenarios

1. **Developer hot-fixes**: Emergency changes in production
2. **Legacy objects**: Existing tables before DBLift adoption
3. **BI tools**: Creating views/materialized views
4. **Performance tuning**: Manual index creation
5. **Third-party tools**: Schema modifications by external systems

## Next Steps
- Try [Scenario 06: CI/CD Integration](../06-ci-cd-integration/)


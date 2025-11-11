# Scenario 04: Checksum Repair

## Objective
Demonstrate undo migrations and repair functionality.

## Prerequisites
- DBLift installed
- Database running
- Migrations applied through V1_0_3

## Steps

### 1. Check Current State

```bash
dblift info --config config/dblift-postgresql.yaml
```

You should see migrations V1_0_0 through V1_0_3 applied.

### 2. Review Undo Migration

Check the undo migration file:
```bash
cat migrations/core/U1_0_3__Remove_orders.sql
```

This migration will roll back the orders tables created in V1_0_3.

### 3. Roll Back to Version 1.0.3

```bash
dblift undo \
  --config config/dblift-postgresql.yaml \
  --target-version 1.0.3
```

**What happens:**
- Executes `U1_0_3__Remove_orders.sql`
- Drops order_items and orders tables
- Updates schema history
- Logs rollback operation

### 4. Verify Rollback

```bash
dblift info --config config/dblift-postgresql.yaml
```

Current version should now be 1.0.3.

### 5. Re-apply Migrations

```bash
dblift migrate --config config/dblift-postgresql.yaml
```

This replays the feature/performance migrations you just undid.

### 6. Simulate Corruption (For Demo)

Connect to database and manually corrupt history:
```bash
docker exec -it dblift-demo-postgres psql -U dblift_user -d dblift_demo
```

```sql
-- Simulate corruption
UPDATE dblift_schema_history 
SET checksum = 'corrupted' 
WHERE version = '1.0.3';

\q
```

### 7. Detect Corruption

```bash
dblift validate --config config/dblift-postgresql.yaml
```

**Expected Output:**
```
❌ Checksum mismatch detected for migration V1_0_3__Add_orders.sql
Expected: <actual_checksum>
Found: corrupted
```

### 8. Repair History Table

```bash
dblift repair --config config/dblift-postgresql.yaml
```

**What happens:**
- Recalculates checksums for all applied migrations
- Updates history table with correct values
- Validates integrity

### 9. Verify Repair

```bash
dblift validate --config config/dblift-postgresql.yaml
```

**Expected Output:**
```
✅ All migrations validated successfully
```

## Advanced: Repair with Baseline

If you have an existing database without migration history:

```bash
dblift baseline \
  --config config/dblift-postgresql.yaml \
  --baseline-version 1.0.0 \
  --baseline-description "Initial baseline"
```

This marks existing schema as version 1.0.0 without running migrations.

## Key Takeaways
- Undo migrations provide controlled rollback
- Always create undo migrations for destructive changes
- Repair command fixes history corruption
- Baseline supports brownfield databases
- Full audit trail maintained
- Safe recovery from errors

## Next Steps
- Try [Scenario 05: Drift Detection](../05-drift-detection/)


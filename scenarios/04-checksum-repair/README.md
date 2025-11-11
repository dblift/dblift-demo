# Scenario 04: Checksum Repair

## Objective
Detect a checksum mismatch in the schema history table and repair it with DBLift.

## Prerequisites
- DBLift installed
- Database running
- Access to the demo migrations

## Steps

### 1. Reset and Apply Migrations

```bash
dblift clean \
  --config config/dblift-postgresql.yaml \
  --drop-schema

dblift migrate \
  --config config/dblift-postgresql.yaml \
  --exclude-tags security
```

This applies the baseline through version **1.3.0** (security-tagged migrations are excluded to keep the demo quick).

### 2. Capture Current History

```bash
dblift info --config config/dblift-postgresql.yaml
```

Confirm the checksum stored for version `1.0.3`.

### 3. Simulate Corruption

Open a psql session to the demo database:

```bash
docker exec -it dblift-demo-postgres psql -U dblift_user -d dblift_demo
```

Run:

```sql
UPDATE dblift_schema_history
SET checksum = 'corrupted'
WHERE version = '1.0.3';
```

Exit with `\q`.

### 4. Detect Corruption

```bash
dblift validate --config config/dblift-postgresql.yaml
```

You should see a checksum mismatch reported for `V1_0_3__Add_orders.sql`.

### 5. Repair the History Table

```bash
dblift repair --config config/dblift-postgresql.yaml
```

DBLift recalculates checksums for all applied migrations and updates the history table.

### 6. Validate Again

```bash
dblift validate --config config/dblift-postgresql.yaml
```

The checksum warning disappears and validation succeeds.

## Key Takeaways
- `dblift validate` compares filesystem and database checksums to detect tampering.
- Manual edits to `dblift_schema_history` are caught immediately.
- `dblift repair` recomputes checksums and restores integrity.
- Schema history queries provide an auditable trail before and after repair.

## Next Steps
- Continue to [Scenario 05: Drift Detection](../05-drift-detection/)


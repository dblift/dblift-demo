# Scenario 09: Targeted Schema Exports

## Objective
Show how DBLift can export managed objects separately from unmanaged ones. This enables brownfield teams to capture a baseline of legacy structures while still generating migration-managed snapshots.

## Prerequisites
- DBLift installed (CLI or Docker)
- Database running with access to the demo schema
- Migrations directory mounted locally (`./migrations`)

## Steps

### 1. Start from a Clean Slate

```bash
dblift clean \
  --config config/dblift-postgresql.yaml \
  --drop-schema

dblift migrate --config config/dblift-postgresql.yaml
```

> Tip: `scripts/scenarios/run_scenario.sh 09` performs these steps automatically in CI.

### 2. Introduce an Unmanaged Table Manually

```bash
psql -h localhost -U dblift_user -d dblift_demo <<'SQL'
CREATE TABLE legacy_audit_log (
    id SERIAL PRIMARY KEY,
    event_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    payload JSONB NOT NULL
);
COMMENT ON TABLE legacy_audit_log IS 'Manually created to simulate brownfield drift';
SQL
```

This table is **not** managed by a migration script, so DBLift tracks it as "unmanaged."

### 3. Export Managed Objects Only

```bash
dblift export \
  --config config/dblift-postgresql.yaml \
  --ignore-unmanaged \
  --output logs/schema/managed.sql
```

**What you get:**
- Only objects created via migrations (`customers`, `orders`, views, functions, etc.)
- No trace of `legacy_audit_log`
- Perfect for generating migration-owned snapshots

### 4. Export Unmanaged Objects Only

```bash
dblift export \
  --config config/dblift-postgresql.yaml \
  --only-unmanaged \
  --output logs/schema/unmanaged.sql
```

**Use cases:**
- Capture baseline DDL for brownfield objects
- Feed into a `baseline` migration
- Document what still needs to be brought under DBLift management

### 5. Inspect the Outputs

```bash
head -n 40 logs/schema/managed.sql
head -n 40 logs/schema/unmanaged.sql
```

Verify that only the intended objects appear in each file.

## Key Takeaways
- `--ignore-unmanaged` keeps exports focused on managed migrations.
- `--only-unmanaged` surfaces legacy objects ripe for baselining.
- You can generate migration files from the unmanaged dump to bring everything under DBLift control.

## Next Steps
- Try [Scenario 07: Brownfield Migration](../07-brownfield-migration/) to see how baselines complement targeted exports.
- Explore `dblift diff --ignore-unmanaged` for day-to-day drift detection in brownfield environments.



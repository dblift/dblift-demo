# Scenario 01: Basic Migration

## Objective
Run your first DBLift migration.

## Steps

### 1. Start Database
```bash
docker-compose up -d postgres
```

### 2. Check Status
```bash
dblift info --config config/dblift-postgresql.yaml
```

### 3. Run Migration
```bash
dblift migrate --config config/dblift-postgresql.yaml
```

### 4. Verify
```bash
dblift info --config config/dblift-postgresql.yaml
```

## Expected Output
You should see that V1_0_0__Initial_schema.sql has been applied.

## Next Steps
- Try [Scenario 02: Validation Rules](../02-validation-rules/)

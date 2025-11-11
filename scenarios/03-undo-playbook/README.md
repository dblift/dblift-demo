# Scenario 03: Undo Playbook

## Objective
Showcase the three ways DBLift can roll back migrations: undoing the latest migration, rewinding to a target version, and removing a specific migration version.

## Steps

### 1. Apply Current Migrations
```bash
dblift migrate \
  --config config/dblift-postgresql.yaml \
  --exclude-tags security
```
This brings the schema to version **1.3.0** while avoiding the security migrations that do not have undo scripts.

### 2. Undo the Latest Migration
```bash
dblift undo \
  --config config/dblift-postgresql.yaml
```
This rolls back only the most recent migration (assuming it has an undo script). Re-apply it with another `dblift migrate` run.

### 3. Undo to a Target Version
```bash
dblift undo \
  --config config/dblift-postgresql.yaml \
  --target-version 1.0.2
```
DBLift rewinds migrations until version `1.0.2` is the current state. Follow up with `dblift migrate` to return to the latest version.

### 4. Undo a Specific Version
```bash
dblift undo \
  --config config/dblift-postgresql.yaml \
  --version 1.1.0
```
This removes only the `1.1.0` migration (and its undo). Run `dblift migrate` again to restore it.

### 5. Inspect History
```bash
dblift info --config config/dblift-postgresql.yaml
```
Confirm the expected version list after each undo/redo step.

## Key Takeaways
- Running `dblift undo` with no extra flags rolls back the most recent migration.
- `--target-version` rewinds multiple migrations in a controlled manner.
- `--version` removes just one migration without affecting earlier versions.
- Always re-run `dblift migrate` to bring the schema back to the desired state.

## Next Steps
- Continue to [Scenario 04: Checksum Repair](../04-checksum-repair/)


# 🚀 DBLift Interactive Demo - Quick Start

Try DBLift hands-on in 5 minutes! This guide shows you real commands with real results.

## Setup (30 seconds)

### Option 1: GitHub Codespace (Easiest)
1. Click the green "Code" button → "Codespaces" → "Create codespace"
2. Wait for environment to load (~1 minute)
3. Run: `docker-compose up -d`

### Option 2: Local with Docker
```bash
git clone https://github.com/dblift/dblift-demo.git
cd dblift-demo
docker-compose up -d
```

## 🎯 Interactive Demo Commands

### 1. Check Migration Status
```bash
docker run --rm \
  -v $(pwd):/workspace \
  --network dblift-demo_default \
  -e DBLIFT_DB_URL=jdbc:postgresql://postgres:5432/dblift_demo \
  -e DBLIFT_DB_USER=dblift_user \
  -e DBLIFT_DB_PASSWORD=dblift_pass \
  -e DBLIFT_DB_SCHEMA=public \
  ghcr.io/cmodiano/dblift:latest info \
  --config /workspace/config/dblift-postgresql.yaml
```

**Expected output:**
```
✓ 0 applied migrations
⧗ 12 pending migrations
• First pending: V1_0_0__Initial_schema.sql
```

---

### 2. Validate Migrations (No Database Needed!)
```bash
docker run --rm \
  -v $(pwd):/workspace \
  ghcr.io/cmodiano/dblift-validation:latest \
  validate-sql /workspace/migrations/ \
  --dialect postgresql \
  --rules-file /workspace/config/.dblift_rules.yaml \
  --format console
```

**Expected output:**
```
✓ All SQL files validated
• Checked 12 migration files
• No violations found
```

---

### 3. Apply Migrations
```bash
docker run --rm \
  -v $(pwd):/workspace \
  --network dblift-demo_default \
  -e DBLIFT_DB_URL=jdbc:postgresql://postgres:5432/dblift_demo \
  -e DBLIFT_DB_USER=dblift_user \
  -e DBLIFT_DB_PASSWORD=dblift_pass \
  -e DBLIFT_DB_SCHEMA=public \
  ghcr.io/cmodiano/dblift:latest migrate \
  --config /workspace/config/dblift-postgresql.yaml
```

**Expected output:**
```
INFO: Connected to database dblift_demo (PostgreSQL 15.14)
INFO: Found 12 pending migration(s)
INFO: Migration lock acquired successfully
INFO: Successfully applied migration core/V1_0_0__Initial_schema.sql
INFO: Successfully applied migration core/V1_0_1__Add_customers.sql
...
✓ 12 migrations applied successfully
```

---

### 4. Check Status Again
```bash
docker run --rm \
  -v $(pwd):/workspace \
  --network dblift-demo_default \
  -e DBLIFT_DB_URL=jdbc:postgresql://postgres:5432/dblift_demo \
  -e DBLIFT_DB_USER=dblift_user \
  -e DBLIFT_DB_PASSWORD=dblift_pass \
  -e DBLIFT_DB_SCHEMA=public \
  ghcr.io/cmodiano/dblift:latest info \
  --config /workspace/config/dblift-postgresql.yaml
```

**Expected output:**
```
✓ 12 applied migrations
✓ 0 pending migrations
✓ Database is up to date
```

---

### 5. Simulate Schema Drift
```bash
# Connect to database and make a manual change
docker exec -it dblift-demo-postgres-1 psql -U dblift_user -d dblift_demo -c \
  "ALTER TABLE users ADD COLUMN phone VARCHAR(20);"
```

**Expected output:**
```
ALTER TABLE
```

---

### 6. Detect Drift
```bash
docker run --rm \
  -v $(pwd):/workspace \
  --network dblift-demo_default \
  -e DBLIFT_DB_URL=jdbc:postgresql://postgres:5432/dblift_demo \
  -e DBLIFT_DB_USER=dblift_user \
  -e DBLIFT_DB_PASSWORD=dblift_pass \
  -e DBLIFT_DB_SCHEMA=public \
  ghcr.io/cmodiano/dblift:latest diff \
  --config /workspace/config/dblift-postgresql.yaml
```

**Expected output:**
```
INFO: Starting drift detection...
INFO: Table 'users' modifications: 
  missing_cols=[], 
  extra_cols=['phone'], 
  modified_cols=[]

ERROR: ✗ Critical differences found: 1 errors
⚠️ Extra column 'phone' found in database but not in migrations
```

---

### 7. Rollback a Migration
```bash
docker run --rm \
  -v $(pwd):/workspace \
  --network dblift-demo_default \
  -e DBLIFT_DB_URL=jdbc:postgresql://postgres:5432/dblift_demo \
  -e DBLIFT_DB_USER=dblift_user \
  -e DBLIFT_DB_PASSWORD=dblift_pass \
  -e DBLIFT_DB_SCHEMA=public \
  ghcr.io/cmodiano/dblift:latest undo \
  --config /workspace/config/dblift-postgresql.yaml \
  --count 1
```

**Expected output:**
```
INFO: Found 1 migration(s) to undo
INFO: Executing undo script: U1_0_3__Remove_orders.sql
INFO: Successfully undone migration core/V1_0_3__Add_orders.sql
✓ Rollback completed successfully
```

---

### 8. Export Current Schema
```bash
docker run --rm \
  -v $(pwd):/workspace \
  --network dblift-demo_default \
  -e DBLIFT_DB_URL=jdbc:postgresql://postgres:5432/dblift_demo \
  -e DBLIFT_DB_USER=dblift_user \
  -e DBLIFT_DB_PASSWORD=dblift_pass \
  -e DBLIFT_DB_SCHEMA=public \
  ghcr.io/cmodiano/dblift:latest export \
  --config /workspace/config/dblift-postgresql.yaml \
  --output /workspace/schema_export.sql
```

**Expected output:**
```
INFO: Exporting schema from public...
INFO: Exported 15 tables
INFO: Exported 4 views
INFO: Exported 7 triggers
INFO: Exported 4 functions
✓ Schema exported to schema_export.sql
```

View the exported schema:
```bash
cat schema_export.sql | head -50
```

---

### 9. Baseline an Existing Database
If you have an existing database and want to start using DBLift:

```bash
docker run --rm \
  -v $(pwd):/workspace \
  --network dblift-demo_default \
  -e DBLIFT_DB_URL=jdbc:postgresql://postgres:5432/dblift_demo \
  -e DBLIFT_DB_USER=dblift_user \
  -e DBLIFT_DB_PASSWORD=dblift_pass \
  -e DBLIFT_DB_SCHEMA=public \
  ghcr.io/cmodiano/dblift:latest baseline \
  --config /workspace/config/dblift-postgresql.yaml \
  --baseline-version 1.0.0 \
  --baseline-description "Initial baseline"
```

**Expected output:**
```
INFO: Creating baseline at version 1.0.0
INFO: Marking all current migrations as applied
✓ Baseline created successfully
```

---

### 10. Clean Database (⚠️ Destructive!)
```bash
docker run --rm \
  -v $(pwd):/workspace \
  --network dblift-demo_default \
  -e DBLIFT_DB_URL=jdbc:postgresql://postgres:5432/dblift_demo \
  -e DBLIFT_DB_USER=dblift_user \
  -e DBLIFT_DB_PASSWORD=dblift_pass \
  -e DBLIFT_DB_SCHEMA=public \
  ghcr.io/cmodiano/dblift:latest clean \
  --config /workspace/config/dblift-postgresql.yaml \
  --drop-schema
```

**Expected output:**
```
WARNING: This will drop all objects in schema 'public'
INFO: Dropping all tables...
INFO: Dropping all views...
INFO: Dropping all functions...
✓ Schema cleaned successfully
```

---

## 🎬 Full Demo Workflow

Run this complete sequence to see all features:

```bash
# 1. Start fresh
docker-compose down -v
docker-compose up -d
sleep 5  # Wait for postgres to be ready

# 2. Check initial status
echo "=== INITIAL STATUS ==="
docker run --rm -v $(pwd):/workspace --network dblift-demo_default \
  -e DBLIFT_DB_URL=jdbc:postgresql://postgres:5432/dblift_demo \
  -e DBLIFT_DB_USER=dblift_user -e DBLIFT_DB_PASSWORD=dblift_pass \
  -e DBLIFT_DB_SCHEMA=public \
  ghcr.io/cmodiano/dblift:latest info --config /workspace/config/dblift-postgresql.yaml

# 3. Apply migrations
echo -e "\n=== APPLYING MIGRATIONS ==="
docker run --rm -v $(pwd):/workspace --network dblift-demo_default \
  -e DBLIFT_DB_URL=jdbc:postgresql://postgres:5432/dblift_demo \
  -e DBLIFT_DB_USER=dblift_user -e DBLIFT_DB_PASSWORD=dblift_pass \
  -e DBLIFT_DB_SCHEMA=public \
  ghcr.io/cmodiano/dblift:latest migrate --config /workspace/config/dblift-postgresql.yaml

# 4. Verify migrations applied
echo -e "\n=== STATUS AFTER MIGRATION ==="
docker run --rm -v $(pwd):/workspace --network dblift-demo_default \
  -e DBLIFT_DB_URL=jdbc:postgresql://postgres:5432/dblift_demo \
  -e DBLIFT_DB_USER=dblift_user -e DBLIFT_DB_PASSWORD=dblift_pass \
  -e DBLIFT_DB_SCHEMA=public \
  ghcr.io/cmodiano/dblift:latest info --config /workspace/config/dblift-postgresql.yaml

# 5. Create manual drift
echo -e "\n=== CREATING DRIFT ==="
docker exec dblift-demo-postgres-1 psql -U dblift_user -d dblift_demo -c \
  "ALTER TABLE users ADD COLUMN phone VARCHAR(20); COMMENT ON COLUMN users.phone IS 'Phone number (drift demo)';"

# 6. Detect drift
echo -e "\n=== DRIFT DETECTION ==="
docker run --rm -v $(pwd):/workspace --network dblift-demo_default \
  -e DBLIFT_DB_URL=jdbc:postgresql://postgres:5432/dblift_demo \
  -e DBLIFT_DB_USER=dblift_user -e DBLIFT_DB_PASSWORD=dblift_pass \
  -e DBLIFT_DB_SCHEMA=public \
  ghcr.io/cmodiano/dblift:latest diff --config /workspace/config/dblift-postgresql.yaml

# 7. Rollback last migration
echo -e "\n=== ROLLING BACK ==="
docker run --rm -v $(pwd):/workspace --network dblift-demo_default \
  -e DBLIFT_DB_URL=jdbc:postgresql://postgres:5432/dblift_demo \
  -e DBLIFT_DB_USER=dblift_user -e DBLIFT_DB_PASSWORD=dblift_pass \
  -e DBLIFT_DB_SCHEMA=public \
  ghcr.io/cmodiano/dblift:latest undo --config /workspace/config/dblift-postgresql.yaml --count 1

# 8. Export schema
echo -e "\n=== EXPORTING SCHEMA ==="
docker run --rm -v $(pwd):/workspace --network dblift-demo_default \
  -e DBLIFT_DB_URL=jdbc:postgresql://postgres:5432/dblift_demo \
  -e DBLIFT_DB_USER=dblift_user -e DBLIFT_DB_PASSWORD=dblift_pass \
  -e DBLIFT_DB_SCHEMA=public \
  ghcr.io/cmodiano/dblift:latest export --config /workspace/config/dblift-postgresql.yaml \
  --output /workspace/schema_export.sql

echo -e "\n=== DEMO COMPLETE ==="
echo "Check schema_export.sql to see the exported schema"
echo "Run 'docker-compose down -v' to clean up"
```

---

## 📖 Learn More

- See [scenarios/](scenarios/) for specific use cases
- Read the full [README.md](README.md) for all features
- Check [docs/](docs/) for best practices and troubleshooting

---

## 🧹 Cleanup

```bash
docker-compose down -v
rm -f schema_export.sql migrate_output.txt drift_output.txt
```


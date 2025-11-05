# DBLift Troubleshooting Guide

Common issues and their solutions.

## Table of Contents

- [Installation Issues](#installation-issues)
- [Connection Problems](#connection-problems)
- [Migration Errors](#migration-errors)
- [Validation Issues](#validation-issues)
- [Performance Problems](#performance-problems)
- [CI/CD Issues](#cicd-issues)

## Installation Issues

### "dblift: command not found"

**Symptoms:**
```bash
$ dblift --version
bash: dblift: command not found
```

**Solutions:**

1. **Check if dblift is in your PATH:**
```bash
# Find dblift location
find / -name dblift 2>/dev/null

# Add to PATH
export PATH="$PATH:/path/to/dblift-linux-x64"

# Make permanent (add to ~/.bashrc or ~/.zshrc)
echo 'export PATH="$PATH:/path/to/dblift-linux-x64"' >> ~/.bashrc
```

2. **Use absolute path:**
```bash
/full/path/to/dblift-linux-x64/dblift --version
```

3. **Use Docker instead:**
```bash
docker run --rm ghcr.io/dblift/dblift:latest --version
```

### "Permission denied"

**Symptoms:**
```bash
$ ./dblift
bash: ./dblift: Permission denied
```

**Solution:**
```bash
chmod +x dblift-linux-x64/dblift
./dblift --version
```

### JDBC Driver Issues

**Symptoms:**
```
Error: Could not find JDBC driver for postgresql
```

**Solution:**
```bash
# Check if drivers are bundled
dblift db list-drivers

# If missing, download from main repo
curl -L -o dblift-linux-x64.tar.gz \
  https://github.com/dblift/dblift/releases/latest/download/dblift-linux-x64.tar.gz
tar xzf dblift-linux-x64.tar.gz
```

## Connection Problems

### "Connection refused"

**Symptoms:**
```
Error: Could not connect to database
Connection refused: localhost:5432
```

**Solutions:**

1. **Check if database is running:**
```bash
# PostgreSQL
docker ps | grep postgres
docker-compose ps postgres

# If not running
docker-compose up -d postgres
```

2. **Check database port:**
```bash
# PostgreSQL default: 5432
# SQL Server default: 1433
# MySQL default: 3306

netstat -an | grep 5432
```

3. **Check firewall:**
```bash
# Allow database port
sudo ufw allow 5432/tcp
```

4. **Verify connection string:**
```yaml
# Correct format
database:
  url: "jdbc:postgresql://localhost:5432/dblift_demo"
  username: "dblift_user"
  password: "dblift_pass"
```

### "Authentication failed"

**Symptoms:**
```
Error: Authentication failed for user 'dblift_user'
```

**Solutions:**

1. **Check credentials:**
```bash
# Test connection manually
psql -h localhost -U dblift_user -d dblift_demo

# Check config file
cat config/dblift-postgresql.yaml
```

2. **Verify user exists:**
```sql
SELECT usename FROM pg_user WHERE usename = 'dblift_user';
```

3. **Check pg_hba.conf (PostgreSQL):**
```bash
# Find pg_hba.conf
docker exec dblift-demo-postgres cat /var/lib/postgresql/data/pg_hba.conf

# Should have:
# host all all 0.0.0.0/0 md5
```

### "Database does not exist"

**Symptoms:**
```
Error: database "dblift_demo" does not exist
```

**Solution:**
```bash
# Create database
docker exec -it dblift-demo-postgres createdb -U dblift_user dblift_demo

# Or via SQL
docker exec -it dblift-demo-postgres psql -U postgres -c "CREATE DATABASE dblift_demo;"
```

## Migration Errors

### "Checksum mismatch"

**Symptoms:**
```
Error: Checksum mismatch for migration V1_0_0__Initial_schema.sql
Expected: abc123
Found: xyz789
```

**Cause:** Migration file was modified after being applied.

**Solutions:**

1. **If file was incorrectly modified, revert it:**
```bash
git checkout migrations/core/V1_0_0__Initial_schema.sql
```

2. **If modification was intentional, repair:**
```bash
# WARNING: Only use if you're certain the file is correct
dblift repair --config config/dblift-postgresql.yaml
```

3. **Create new migration instead:**
```sql
-- Don't modify V1_0_0, create V1_0_1 instead
-- V1_0_1__Fix_schema.sql
ALTER TABLE users ADD COLUMN email VARCHAR(100);
```

### "Migration failed: Table already exists"

**Symptoms:**
```
Error: relation "users" already exists
```

**Cause:** Migration was partially applied or run manually.

**Solutions:**

1. **Check what's applied:**
```bash
dblift info --config config/dblift-postgresql.yaml
```

2. **Baseline if necessary:**
```bash
dblift baseline --baseline-version 1.0.0
```

3. **Or drop and recreate:**
```sql
DROP TABLE IF EXISTS users CASCADE;
-- Then re-run migration
```

### "Foreign key violation"

**Symptoms:**
```
Error: insert or update on table "order_items" violates foreign key constraint
```

**Cause:** Data doesn't satisfy foreign key constraint.

**Solution:**
```sql
-- Check orphaned records
SELECT * FROM order_items oi
LEFT JOIN orders o ON oi.order_id = o.id
WHERE o.id IS NULL;

-- Fix orphaned records
DELETE FROM order_items WHERE order_id NOT IN (SELECT id FROM orders);

-- Or add missing parent records
INSERT INTO orders (id, ...) VALUES (...);
```

### "Version conflict"

**Symptoms:**
```
Error: Version 1.5.0 conflicts with existing version 1.4.9
```

**Cause:** Version numbers not sequential.

**Solution:**
```bash
# Check applied versions
dblift info --config config.yaml

# Rename new migration to next sequential version
mv V1_5_0__New_feature.sql V1_4_10__New_feature.sql
```

## Validation Issues

### "Validation failed: require_primary_key"

**Symptoms:**
```
ERROR: Table 'users' must have a primary key
```

**Solution:**
```sql
-- Add primary key
ALTER TABLE users ADD PRIMARY KEY (id);

-- Or create table with primary key
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    ...
);
```

### "Validation failed: require_audit_columns"

**Symptoms:**
```
ERROR: Tables must have audit columns (created_at, updated_at, created_by)
```

**Solution:**
```sql
ALTER TABLE users 
ADD COLUMN created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
ADD COLUMN updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
ADD COLUMN created_by VARCHAR(50) DEFAULT 'system' NOT NULL;
```

### "Validation rule not found"

**Symptoms:**
```
Error: Validation rule 'custom_rule' not found in rules file
```

**Solution:**
```bash
# Check rules file exists
cat config/.dblift_rules.yaml

# Verify rule name
grep "name: custom_rule" config/.dblift_rules.yaml

# Check file path in config
cat config/dblift-postgresql.yaml | grep rules_file
```

## Performance Problems

### "Migration is taking too long"

**Symptoms:**
Migration runs for hours without completing.

**Solutions:**

1. **Add indexes concurrently (PostgreSQL):**
```sql
CREATE INDEX CONCURRENTLY idx_users_email ON users(email);
```

2. **Batch large updates:**
```sql
DO $$
BEGIN
  FOR i IN 0..999 LOOP
    UPDATE users 
    SET status = 'active' 
    WHERE id % 1000 = i;
    COMMIT;
  END LOOP;
END $$;
```

3. **Check blocking queries:**
```sql
-- PostgreSQL
SELECT pid, query, state 
FROM pg_stat_activity 
WHERE state != 'idle';
```

4. **Disable triggers temporarily:**
```sql
ALTER TABLE users DISABLE TRIGGER ALL;
-- Run migration
ALTER TABLE users ENABLE TRIGGER ALL;
```

### "Out of memory"

**Symptoms:**
```
Error: Out of memory
```

**Solutions:**

1. **Increase batch size limit:**
```yaml
migrations:
  batch_size: 1000  # Reduce if OOM
```

2. **Use streaming for large data:**
```sql
-- Instead of loading all at once
CREATE TABLE new_table AS SELECT * FROM old_table;

-- Use chunked approach
INSERT INTO new_table
SELECT * FROM old_table LIMIT 10000 OFFSET 0;
-- Repeat with increasing offset
```

## CI/CD Issues

### "GitHub Actions failing"

**Symptoms:**
Workflow fails with DBLift errors.

**Solutions:**

1. **Check DBLift version:**
```yaml
# Pin to specific version
- name: Download DBLift
  run: |
    curl -L -o dblift.tar.gz \
      https://github.com/dblift/dblift/releases/download/v1.0.0/dblift-linux-x64.tar.gz
```

2. **Check secrets:**
```bash
# Verify secrets are set
# Repository Settings → Secrets → Actions
```

3. **Test locally:**
```bash
# Reproduce issue locally
docker run --rm -v $(pwd):/workspace ubuntu:latest bash -c "
  cd /workspace
  curl -L -o dblift.tar.gz URL
  tar xzf dblift.tar.gz
  ./dblift-linux-x64/dblift validate-sql migrations/
"
```

### "SARIF upload failed"

**Symptoms:**
```
Error: Unable to upload SARIF file
```

**Solutions:**

1. **Check SARIF file exists:**
```yaml
- name: Debug SARIF
  run: |
    ls -la validation-results.sarif
    cat validation-results.sarif
```

2. **Validate SARIF format:**
```bash
# Use SARIF validator
npm install -g @microsoft/sarif-multitool
sarif-multitool validate validation-results.sarif
```

3. **Check permissions:**
```yaml
permissions:
  security-events: write  # Required for SARIF upload
```

## Drift Detection Issues

### "False positive drift detected"

**Symptoms:**
Drift reported but schema looks correct.

**Solutions:**

1. **Ignore specific objects:**
```yaml
# config/dblift-postgresql.yaml
drift:
  ignore_patterns:
    - "temp_*"      # Ignore temp tables
    - "v_bi_*"      # Ignore BI views
```

2. **Use ignore-unmanaged flag:**
```bash
dblift diff --ignore-unmanaged
```

3. **Baseline current state:**
```bash
dblift baseline --baseline-version current
```

### "Drift not detected"

**Symptoms:**
Manual changes made but drift not reported.

**Solutions:**

1. **Check drift detection scope:**
```bash
# Full drift check
dblift diff --config config.yaml --verbose
```

2. **Verify table is managed:**
```bash
dblift info --config config.yaml
```

3. **Check drift configuration:**
```yaml
drift:
  enabled: true
  check_columns: true
  check_indexes: true
  check_constraints: true
```

## Getting Help

If you can't resolve the issue:

1. **Check logs:**
```bash
cat logs/dblift_*.log
```

2. **Enable debug logging:**
```yaml
logging:
  level: DEBUG
```

3. **Search issues:**
https://github.com/dblift/dblift/issues

4. **Create new issue:**
Include:
- DBLift version (`dblift --version`)
- Database type and version
- Full error message
- Relevant configuration
- Steps to reproduce

5. **Community support:**
- Slack: https://dblift-community.slack.com
- Forum: https://community.dblift.io

## Quick Reference

### Diagnostic Commands

```bash
# Check version
dblift --version

# List JDBC drivers
dblift db list-drivers

# Test connection
dblift db check-connection --config config.yaml

# Check migration status
dblift info --config config.yaml

# Validate migrations
dblift validate --config config.yaml

# Check for drift
dblift diff --config config.yaml

# View history
dblift history --config config.yaml
```

### Emergency Commands

```bash
# Repair corrupted history
dblift repair --config config.yaml

# Baseline existing database
dblift baseline --baseline-version 1.0.0

# Rollback to version
dblift undo --target-version 1.4.0

# Dry run migration
dblift migrate --dry-run
```


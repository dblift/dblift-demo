# DBLift Best Practices

This guide provides best practices for using DBLift effectively in production environments.

## Migration Design

### Keep Migrations Small and Focused

✅ **Good:**
```sql
-- V1_0_1__Add_email_to_users.sql
ALTER TABLE users ADD COLUMN email VARCHAR(100) UNIQUE;
CREATE INDEX idx_users_email ON users(email);
```

❌ **Bad:**
```sql
-- V1_0_1__Big_update.sql
-- 500 lines of multiple unrelated changes
ALTER TABLE users ...;
CREATE TABLE products ...;
ALTER TABLE orders ...;
-- etc.
```

**Why:** Small migrations are easier to review, test, and rollback if needed.

### One Logical Change Per Migration

Each migration should represent a single logical change:
- Adding a table
- Adding a column
- Creating an index
- Modifying a constraint

### Use Descriptive Names

✅ **Good:**
- `V1_2_0__Add_user_preferences_table.sql`
- `V1_2_1__Add_email_notification_column.sql`

❌ **Bad:**
- `V1_2_0__Update.sql`
- `V1_2_1__Fix.sql`

### Always Add Comments

```sql
-- DBLift Demo - Add User Preferences
-- Description: Create user preferences table for application settings
-- Author: Platform Team
-- Date: 2024-02-20
-- Tags: user-mgmt, features

CREATE TABLE user_preferences (
    -- User reference (FK to users table)
    user_id INTEGER UNIQUE NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    
    -- UI theme preference
    theme VARCHAR(20) DEFAULT 'light' CHECK (theme IN ('light', 'dark', 'auto')),
    
    -- Standard audit columns
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by VARCHAR(50) DEFAULT 'system' NOT NULL
);
```

## Validation

### Enable Validation in All Environments

```yaml
# config/dblift-prod.yaml
validation:
  enabled: true
  fail_on_violations: true
  severity_threshold: "error"
```

### Create Custom Rules for Your Organization

```yaml
# .dblift_rules.yaml
rules:
  - name: require_team_approval_comment
    type: pattern
    regex: "-- Approved by: [A-Z][a-z]+ [A-Z][a-z]+"
    message: "All production migrations must have approval comment"
    severity: error
```

### Validate Locally Before Committing

```bash
# Add to your workflow
dblift validate-sql migrations/ \
  --dialect postgresql \
  --rules-file config/.dblift_rules.yaml
```

## Version Naming

### Follow Semantic Versioning

- **Major** (1.x.x): Breaking changes, major features
- **Minor** (x.1.x): New features, backward compatible
- **Patch** (x.x.1): Bug fixes, small changes

### Reserve Version Ranges

- `1.x.x` - Core schema
- `2.x.x` - Features
- `3.x.x` - Module A
- `4.x.x` - Module B
- `9.x.x` - Performance/optimization

### Never Reuse Version Numbers

Once a version is applied to any environment, never reuse it.

## Deployment

### Progressive Deployment

Always follow this order:
1. Development
2. QA/Testing
3. Staging
4. Production

### Never Skip Environments

❌ **Don't:**
```bash
# Deploying directly to production
git push origin main  # Goes straight to prod
```

✅ **Do:**
```bash
# Test in dev first
git push origin develop  # Deploys to dev
# Verify, then promote to staging
git push origin staging  # Deploys to staging
# Verify, then promote to production
git push origin main  # Deploys to prod with approval
```

### Always Backup Before Migration

```bash
# PostgreSQL
pg_dump -U user -d database > backup-$(date +%Y%m%d-%H%M%S).sql

# SQL Server
sqlcmd -S server -d database -Q "BACKUP DATABASE ..."

# MySQL
mysqldump -u user -p database > backup.sql
```

### Use Dry Run in Production

```bash
# Review changes before applying
dblift migrate \
  --config config-prod.yaml \
  --dry-run

# Then apply for real
dblift migrate --config config-prod.yaml
```

## CI/CD Integration

### Mandatory PR Validation

```yaml
# .github/workflows/validate-sql.yml
- name: Validate SQL
  run: |
    dblift validate-sql migrations/ \
      --fail-on-violations \
      --severity-threshold warning
```

Block PR merges if validation fails.

### Require Code Reviews

- Minimum 2 approvals for production migrations
- At least 1 DBA review for complex changes
- Automated validation must pass

### Scheduled Drift Detection

```yaml
# Run daily at 9 AM
on:
  schedule:
    - cron: '0 9 * * *'
```

Create issues automatically when drift detected.

### Use Environment Secrets

Never commit credentials:

```yaml
# ✅ Good - use secrets
env:
  DB_PASSWORD: ${{ secrets.PROD_DB_PASSWORD }}

# ❌ Bad - hardcoded
env:
  DB_PASSWORD: "mypassword123"
```

## Schema Management

### All Changes Via Migrations

**Never make manual changes** to production schema.

If emergency fix needed:
1. Make manual change
2. Immediately create migration to match
3. Document in drift report
4. Apply migration to other environments

### Monitor Drift Continuously

```bash
# Daily cron job
0 9 * * * dblift diff --config prod.yaml || notify-team
```

### Document Exceptions

If you must have unmanaged objects:

```yaml
# .dblift_config.yaml
unmanaged_objects:
  tables:
    - legacy_temp_table  # BI tool creates this
    - external_sync_data  # ETL process manages this
  reason: "Documented exception - see ARCHITECTURE.md"
```

## Testing

### Test Migrations Thoroughly

1. **Unit test:** Migration syntax valid
2. **Integration test:** Migration applies cleanly
3. **Data test:** Existing data preserved
4. **Performance test:** Migration completes in acceptable time
5. **Rollback test:** Undo migration works

### Test with Realistic Data Volume

```bash
# Load production-like data volume
dblift migrate --config test.yaml

# Measure performance
time dblift migrate --config test.yaml
```

### Test Undo Migrations

```bash
# Apply migration
dblift migrate --target-version 1.5.0

# Test rollback
dblift undo --target-version 1.4.0

# Verify state
dblift info
```

## Performance

### Create Indexes Concurrently

```sql
-- PostgreSQL
CREATE INDEX CONCURRENTLY idx_users_email ON users(email);

-- Avoids table locking
```

### Add Columns with Defaults Carefully

```sql
-- Can be slow on large tables
ALTER TABLE users ADD COLUMN status VARCHAR(20) DEFAULT 'active';

-- Better: Add without default, then update in batches
ALTER TABLE users ADD COLUMN status VARCHAR(20);
UPDATE users SET status = 'active' WHERE id BETWEEN 1 AND 10000;
UPDATE users SET status = 'active' WHERE id BETWEEN 10001 AND 20000;
-- etc.
ALTER TABLE users ALTER COLUMN status SET DEFAULT 'active';
```

### Batch Large Data Changes

```sql
-- Instead of one massive UPDATE
DO $$
DECLARE
    batch_size INTEGER := 1000;
    affected INTEGER;
BEGIN
    LOOP
        UPDATE products 
        SET updated_at = CURRENT_TIMESTAMP
        WHERE id IN (
            SELECT id FROM products 
            WHERE updated_at IS NULL 
            LIMIT batch_size
        );
        
        GET DIAGNOSTICS affected = ROW_COUNT;
        EXIT WHEN affected = 0;
        
        RAISE NOTICE 'Updated % rows', affected;
        COMMIT;  -- Commit each batch
    END LOOP;
END $$;
```

## Security

### Audit Columns on All Tables

Always include:
```sql
created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
created_by VARCHAR(50) DEFAULT 'system' NOT NULL
```

### Hash Sensitive Data

```sql
-- ✅ Good
password_hash VARCHAR(255) NOT NULL

-- ❌ Bad
password VARCHAR(100) NOT NULL
```

### Use Least Privilege

Migration user should have only necessary permissions:
```sql
-- Create migration-specific user
CREATE USER dblift_migration WITH PASSWORD 'secure_pass';

-- Grant only schema modification rights
GRANT CREATE, ALTER, DROP ON SCHEMA public TO dblift_migration;

-- Don't grant SUPERUSER
```

### Encrypt Connection Strings

```bash
# Use encrypted environment variables
export DB_PASSWORD=$(decrypt-secret prod-db-password)
dblift migrate --config prod.yaml
```

## Documentation

### Maintain Migration Log

Create `MIGRATIONS.md`:
```markdown
# Migration History

## v1.5.0 - 2024-02-20
- Added user preferences table
- Added notification system
- Team: Platform
- Reviewer: DBA Team

## v1.4.0 - 2024-02-10
- Added order management
- Added inventory tracking
- Team: Backend
- Reviewer: Lead Engineer
```

### Document Dependencies

```sql
-- V1_5_0__Add_user_preferences.sql
-- DEPENDENCIES:
--   - V1_0_0__Initial_schema.sql (users table required)
--   - PostgreSQL 12+ (JSONB support)
```

### Keep README Updated

Update project README when:
- Adding new migration patterns
- Changing deployment process
- Updating validation rules
- Modifying CI/CD pipelines

## Error Handling

### Plan for Failures

```bash
# Wrap migrations in transactions where possible
BEGIN;
-- migration SQL
COMMIT;
-- On error: ROLLBACK happens automatically
```

### Have Rollback Plan

1. Create undo migration beforehand
2. Test undo migration
3. Document rollback procedure
4. Keep backup ready

### Monitor Deployments

```bash
# Send notification on completion
dblift migrate --config prod.yaml && \
  notify-team "Production migration completed successfully"
```

## Team Collaboration

### Clear Ownership

```sql
-- V1_5_0__Add_analytics[analytics,team-data].sql
-- Team: Data Analytics
-- Owner: @alice
-- Reviewer: @bob
```

### Code Reviews

Review checklist:
- [ ] Migration naming correct?
- [ ] Version number sequential?
- [ ] Undo migration provided?
- [ ] Validation rules pass?
- [ ] Performance acceptable?
- [ ] Documentation included?
- [ ] Tests added?

### Communication

- Announce migrations in team channel
- Schedule production deployments
- Notify on completion
- Document issues/learnings

## Common Pitfalls to Avoid

### ❌ Don't Modify Applied Migrations

Once applied to any environment, migrations are immutable.

### ❌ Don't Mix DDL and DML

Separate schema changes from data changes:
```sql
-- V1_5_0__Add_status_column.sql (DDL)
ALTER TABLE users ADD COLUMN status VARCHAR(20);

-- V1_5_1__Populate_status_column.sql (DML)
UPDATE users SET status = 'active';
```

### ❌ Don't Forget Foreign Key Indexes

```sql
-- Always add index on foreign key
CREATE TABLE orders (
    customer_id INTEGER NOT NULL REFERENCES customers(id)
);
CREATE INDEX idx_orders_customer_id ON orders(customer_id);
```

### ❌ Don't Use SELECT * in Migrations

```sql
-- ✅ Good
INSERT INTO new_table (id, name, email)
SELECT id, name, email FROM old_table;

-- ❌ Bad
INSERT INTO new_table SELECT * FROM old_table;
```

### ❌ Don't Ignore Warnings

Warnings often indicate real problems:
- Missing indexes on foreign keys
- Tables without primary keys
- Unvalidated constraints

## Summary Checklist

- [ ] Migrations are small and focused
- [ ] Descriptive names and comments
- [ ] Validation enabled and passing
- [ ] Tested in dev/staging before production
- [ ] Backup created before deployment
- [ ] Undo migration created and tested
- [ ] CI/CD validates automatically
- [ ] Drift detection scheduled
- [ ] Documentation updated
- [ ] Team notified

## Resources

- [DBLift Documentation](https://docs.dblift.io)
- [Flyway Best Practices](https://flywaydb.org/documentation/concepts/migrations)
- [Liquibase Best Practices](https://www.liquibase.org/get-started/best-practices)
- [PostgreSQL Migration Best Practices](https://www.postgresql.org/docs/current/ddl.html)


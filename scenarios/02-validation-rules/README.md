

# Scenario 02: Validation Rules

## Objective
Demonstrate SQL validation with custom business rules.

## Prerequisites
- DBLift installed
- Review `config/.dblift_rules.yaml`

## Steps

### 1. Review Validation Rules

Check the validation rules configuration:
```bash
cat config/.dblift_rules.yaml
```

Key rules include:
- Naming conventions (snake_case tables, lowercase columns)
- Required elements (primary keys, audit columns)
- Anti-patterns (SELECT *, DELETE without WHERE)
- Performance rules (foreign key indexes)

### 2. Validate Existing Migrations

```bash
dblift validate-sql migrations/ \
  --dialect postgresql \
  --rules-file config/.dblift_rules.yaml \
  --format console
```

**Expected Output:**
```
✅ Validation passed! No violations found.
```

### 3. Create a Bad Migration (Intentional Violations)

Create `migrations/test/V9_9_9__bad_example.sql`:

```sql
-- This migration has multiple violations for demo purposes

-- Violation 1: No primary key
CREATE TABLE BadTable (
    name VARCHAR(100)
);

-- Violation 2: No audit columns
CREATE TABLE AnotherBadTable (
    id INTEGER PRIMARY KEY,
    value TEXT
);

-- Violation 3: Foreign key without index
CREATE TABLE orders_bad (
    id INTEGER PRIMARY KEY,
    customer_id INTEGER REFERENCES customers(id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by VARCHAR(50) DEFAULT 'system'
);

-- Violation 4: SELECT *
INSERT INTO BadTable SELECT * FROM users;

-- Violation 5: DELETE without WHERE
DELETE FROM BadTable;
```

### 4. Run Validation on Bad Migration

```bash
dblift validate-sql migrations/test/ \
  --dialect postgresql \
  --rules-file config/.dblift_rules.yaml \
  --format console
```

**Expected Output:**
```
❌ Validation Results
═══════════════════════════════════

📄 migrations/test/V9_9_9__bad_example.sql

  ❌ ERROR [require_primary_key] Line 4
     All tables must have a primary key (table: BadTable)

  ❌ ERROR [require_audit_columns] Line 8
     Tables must have audit columns (table: AnotherBadTable)
     Missing: created_at, updated_at, created_by

  ⚠️  WARNING [foreign_keys_must_have_indexes] Line 17
     Foreign key on customer_id must have an index (table: orders_bad)

  ℹ️  INFO [no_select_star] Line 26
     Avoid SELECT * - explicitly list columns

  ❌ ERROR [require_where_in_delete] Line 29
     DELETE without WHERE clause detected

═══════════════════════════════════
Files checked: 1
Violations: 3 errors, 1 warning, 1 info
```

### 5. Generate HTML Report

```bash
dblift validate-sql migrations/test/ \
  --dialect postgresql \
  --rules-file config/.dblift_rules.yaml \
  --format html \
  --output validation-report.html
```

Open `validation-report.html` in your browser to see detailed violations.

### 6. Fix Violations

Create `migrations/test/V9_9_9__good_example.sql`:

```sql
-- Fixed version with all violations resolved

CREATE TABLE GoodTable (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by VARCHAR(50) DEFAULT 'system' NOT NULL
);

CREATE TABLE AnotherGoodTable (
    id INTEGER PRIMARY KEY,
    value TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by VARCHAR(50) DEFAULT 'system' NOT NULL
);

CREATE TABLE orders_good (
    id INTEGER PRIMARY KEY,
    customer_id INTEGER REFERENCES customers(id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by VARCHAR(50) DEFAULT 'system' NOT NULL
);
CREATE INDEX idx_orders_good_customer_id ON orders_good(customer_id);

INSERT INTO GoodTable (name, created_by) 
SELECT username, 'migration' FROM users;

DELETE FROM GoodTable WHERE created_at < CURRENT_DATE - INTERVAL '1 year';
```

### 7. Validate Fixed Migration

```bash
dblift validate-sql migrations/test/V9_9_9__good_example.sql \
  --dialect postgresql \
  --rules-file config/.dblift_rules.yaml
```

**Expected Output:**
```
✅ Validation passed! No violations found.
```

## Key Takeaways
- Validation catches issues before deployment
- Custom rules enforce organizational standards
- Multiple severity levels (error, warning, info)
- Can be integrated into CI/CD pipelines
- HTML reports provide detailed analysis

## Next Steps
- Try [Scenario 03: Rollback & Recovery](../03-rollback-recovery/)


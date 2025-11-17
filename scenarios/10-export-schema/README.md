# Scenario 09: Schema Export

## Objective
Demonstrate DBLift's schema export capabilities with two main features:
1. **SQL Export** - Export the database schema as a SQL file for baselining
2. **Schema Model Export** - Export the database schema as a JSON model for programmatic comparison

## Prerequisites
- DBLift installed (CLI or Docker)
- Database running with access to the demo schema
- Migrations applied to the database

## Overview

DBLift's `export-schema` command provides two export formats:

- **SQL Export**: Generates a SQL file containing all schema objects (tables, views, functions, etc.). This can be used as a baseline for brownfield migrations or for creating migration scripts.
- **JSON Schema Model**: Generates a structured JSON representation of the database schema. This can be used for programmatic comparison with live databases to detect schema changes.

## Steps

### 1. Prepare the Database

```bash
dblift migrate --config config/dblift-postgresql.yaml
```

> Tip: `scripts/scenarios/run_scenario.sh 09` performs these steps automatically in CI.

### 2. Export Schema as SQL File

```bash
dblift export-schema \
  --config config/dblift-postgresql.yaml \
  --output schema.sql \
  --output-format sql
```

**What you get:**
- Complete SQL DDL for all schema objects
- Tables with their structure, constraints, and indexes
- Views, functions, triggers, and other database objects
- Ready to use as a baseline for brownfield migrations

**Use cases:**
- Create a baseline snapshot of an existing database
- Generate migration scripts from the exported SQL
- Document the current schema state
- Use as a reference for schema comparison

**Example output preview:**
```sql
-- Exported schema from dblift_demo
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) NOT NULL,
    ...
);
CREATE TABLE customers (
    id SERIAL PRIMARY KEY,
    contact_name VARCHAR(100) NOT NULL,
    ...
);
-- ... more objects
```

### 3. Export Schema as JSON Model

```bash
dblift export-schema \
  --config config/dblift-postgresql.yaml \
  --output-format model \
  --output schema.json
```

**What you get:**
- Structured JSON representation of the entire schema
- Tables, columns, data types, constraints in JSON format
- Views, functions, and other objects as structured data
- Perfect for programmatic analysis and comparison

**Use cases:**
- Compare schema models between different database instances
- Detect schema changes programmatically
- Integrate with CI/CD pipelines for schema validation
- Generate reports or documentation from schema metadata

**Example output preview:**
```json
{
  "schema": "dblift_demo",
  "tables": [
    {
      "name": "users",
      "columns": [
        {
          "name": "id",
          "type": "SERIAL",
          "nullable": false,
          "primaryKey": true
        },
        {
          "name": "username",
          "type": "VARCHAR(50)",
          "nullable": false,
          "unique": true
        }
      ]
    }
  ],
  "views": [...],
  "functions": [...]
}
```

### 4. Inspect the Exports

```bash
# View SQL export
head -n 50 schema.sql

# View JSON model
head -n 80 schema.json | jq .
```

## Key Takeaways

### SQL Export
- **Purpose**: Human-readable SQL DDL for baselining and migration script generation
- **Format**: Standard SQL CREATE statements
- **Best for**: Creating baseline migrations, documenting schema, manual review

### JSON Schema Model
- **Purpose**: Machine-readable schema representation for programmatic comparison
- **Format**: Structured JSON with schema metadata
- **Best for**: Automated schema comparison, CI/CD integration, change detection

### When to Use Each

**Use SQL Export when:**
- You need to create a baseline migration from an existing database
- You want human-readable schema documentation
- You're doing brownfield migration onboarding
- You need to generate migration scripts manually

**Use JSON Model when:**
- You want to compare schemas programmatically
- You're building automated schema validation tools
- You need to integrate schema checks into CI/CD pipelines
- You want to detect schema drift automatically

## Next Steps
- Revisit [Scenario 08: Brownfield Migration](../08-brownfield-migration/) to see how SQL exports can be used for baselining.
- Explore [Scenario 05: Drift Detection](../05-drift-detection/) to see how schema comparison works in practice.



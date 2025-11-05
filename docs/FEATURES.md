# DBLift Features Overview

This document provides a comprehensive overview of all DBLift features demonstrated in this repository.

## Table of Contents

- [Migration Types](#migration-types)
- [Validation & Quality](#validation--quality)
- [Schema Management](#schema-management)
- [CI/CD Integration](#cicd-integration)
- [Logging & Reporting](#logging--reporting)
- [Advanced Features](#advanced-features)

## Migration Types

### Versioned Migrations (V)

Sequential schema changes that run exactly once.

**Naming Convention:**
```
V<major>_<minor>_<patch>__<description>[tags].sql
```

**Examples:**
- `V1_0_0__Initial_schema.sql`
- `V1_0_1__Add_customers.sql`
- `V1_1_0__Add_user_preferences[user-mgmt].sql`

**Key Features:**
- Runs in strict version order
- Checksum validation prevents tampering
- Tracked in schema history table
- Supports tags for selective deployment

### Repeatable Migrations (R)

Migrations that re-execute when their content changes.

**Naming Convention:**
```
R__<description>.sql
```

**Examples:**
- `R__Create_views.sql`
- `R__Create_functions.sql`
- `R__Create_stored_procedures.sql`

**Use Cases:**
- Database views
- Stored procedures
- Functions
- Triggers

**Key Features:**
- Re-executes on content change (checksum-based)
- Always runs after versioned migrations
- Idempotent by nature

### Undo Migrations (U)

Rollback capability for versioned migrations.

**Naming Convention:**
```
U<major>_<minor>_<patch>__<description>.sql
```

**Examples:**
- `U1_0_3__Remove_orders.sql` (undoes V1_0_3)

**Key Features:**
- Paired with versioned migrations
- Controlled rollback to specific version
- Full audit trail maintained
- Data safety checks

## Validation & Quality

### SQL Syntax Validation

Validates SQL syntax before execution.

```bash
dblift validate-sql migrations/ --dialect postgresql
```

**Features:**
- Dialect-specific validation (PostgreSQL, SQL Server, MySQL, Oracle)
- Catches syntax errors before deployment
- Validates references to tables/columns
- Type checking

### Business Rules Validation

Custom validation rules for organizational standards.

**Rule Categories:**
1. **Naming Conventions**
   - snake_case tables
   - Lowercase columns
   - Prefixed indexes (idx_)

2. **Required Elements**
   - Primary keys on all tables
   - Audit columns (created_at, updated_at, created_by)
   - Table comments/documentation

3. **Anti-Patterns**
   - SELECT * detection
   - DELETE without WHERE
   - UPDATE without WHERE
   - TRUNCATE warnings
   - DROP TABLE restrictions

4. **Performance Rules**
   - Foreign keys must have indexes
   - Cartesian product detection
   - Missing WHERE clauses
   - Correlated subqueries

**Configuration:**
```yaml
# .dblift_rules.yaml
rules:
  - name: require_primary_key
    type: presence
    target: table
    must_have_primary_key: true
    message: "All tables must have a primary key"
    severity: error
```

### Severity Levels

- **ERROR**: Blocks deployment
- **WARNING**: Logged but allows deployment
- **INFO**: Informational only

## Schema Management

### Drift Detection

Identifies manual schema changes outside migrations.

```bash
dblift diff --config config/dblift-postgresql.yaml
```

**Detects:**
- Extra/missing columns
- Modified columns
- Extra/missing indexes
- Extra/missing constraints
- Unmanaged tables (brownfield support)

**Reports:**
- TEXT format (console)
- JSON format (automation)
- HTML format (detailed analysis)

### Baseline

Adopt existing databases without migration history.

```bash
dblift baseline \
  --baseline-version 1.0.0 \
  --baseline-description "Production baseline"
```

**Use Cases:**
- Brownfield databases
- Legacy system migration
- Gradual DBLift adoption

### Repair

Fix corrupted migration history.

```bash
dblift repair --config config/dblift-postgresql.yaml
```

**Fixes:**
- Checksum mismatches
- Missing history entries
- Corrupted metadata

## CI/CD Integration

### GitHub Actions

Pre-built workflows for:
- **SQL Validation** - PR checks
- **Auto-Deployment** - Dev/staging
- **Production Deployment** - Manual approval
- **Drift Detection** - Scheduled monitoring

**SARIF Integration:**
- GitHub Code Scanning
- Inline PR annotations
- Security tab integration
- Trend analysis

### GitLab CI

Example pipeline configuration included.

### Pre-commit Hooks

Local validation before commit:
```bash
pre-commit install
```

## Logging & Reporting

### Multi-Format Logging

Generate logs in multiple formats simultaneously:

```bash
dblift migrate --log-format text,json,html
```

**Formats:**
- **TEXT**: Traditional log files
- **JSON**: Machine-readable for automation
- **HTML**: Interactive reports with charts

### Migration Journal

Detailed execution tracking:
- SQL statement timing
- Performance metrics by object type
- Success/failure status
- Error diagnostics

### Performance Metrics

Track execution performance:
- Total migration time
- Per-statement timing
- Object creation performance
- Index build timing

## Advanced Features

### Tag-Based Deployment

Selective migration execution:

```bash
# Deploy specific features
dblift migrate --tags user-mgmt,notifications

# Exclude features
dblift migrate --exclude-tags analytics
```

**Use Cases:**
- Feature flags
- Module-based deployment
- Customer-specific features
- Gradual rollouts

### Multi-Directory Support

Organize migrations across modules:

```yaml
migrations:
  directory: "./migrations/core"
  directories:
    - "./migrations/features"
    - "./modules/inventory/migrations"
    - "./modules/crm/migrations"
```

**Benefits:**
- Team independence
- Module-based organization
- Monorepo support

### Environment Variables

Dynamic configuration:

```yaml
database:
  url: "${DATABASE_URL}"
  username: "${DB_USER}"
  password: "${DB_PASSWORD}"
```

### Placeholders

Dynamic SQL generation:

```sql
-- Use placeholder: ${schema_name}
CREATE TABLE ${schema_name}.users (...);
```

### Dry Run

Preview changes without executing:

```bash
dblift migrate --dry-run
```

### Target Version

Migrate to specific version:

```bash
dblift migrate --target-version 1.5.0
```

## Database Support

### Supported Databases

- ✅ PostgreSQL (9.4+)
- ✅ SQL Server (2012+)
- ✅ MySQL (5.7+)
- ✅ Oracle (11g+)
- ✅ DB2 (10.5+)

### JDBC Drivers

Bundled JDBC drivers included:
- PostgreSQL 42.7.5
- SQL Server 12.10.0
- MySQL Connector/J 9.3.0
- Oracle JDBC 17
- DB2 JDBC 4

### Dialect-Specific Features

Automatic dialect detection and optimization:
- Native data types
- Index types (B-tree, GIN, GIST)
- Constraint syntax
- Stored procedure syntax

## Security Features

### Credential Management

- Environment variable support
- Secrets management integration
- No plaintext passwords in configs

### Audit Trail

Complete audit logging:
- Who ran migrations
- When they ran
- What changed
- Success/failure status

### Access Control

- Role-based execution
- Read-only validation mode
- Separate dev/prod credentials

## Performance Features

### Parallel Execution

(Future feature)
```bash
dblift migrate --parallel
```

### Batch Processing

Efficient bulk operations:
- Batched inserts
- Bulk index creation
- Transaction management

### Connection Pooling

Built-in connection pool management.

## Integration Features

### REST API

(Future feature) RESTful API for automation.

### Webhooks

(Future feature) Event notifications.

### Metrics Export

Prometheus/Grafana integration ready.

## Best Practices

### Migration Design

1. **Keep migrations small** - One logical change per migration
2. **Test thoroughly** - Dev → Staging → Production
3. **Use undo migrations** - For reversible changes
4. **Document changes** - Clear descriptions and comments

### Validation

1. **Enable validation** - Always validate before deployment
2. **Custom rules** - Enforce organizational standards
3. **Severity levels** - Error for critical, warning for optional

### CI/CD

1. **Automate validation** - PR checks mandatory
2. **Progressive deployment** - Dev → Staging → Prod
3. **Manual approval** - Production requires human review
4. **Monitor drift** - Scheduled daily checks

### Schema Management

1. **Track everything** - All changes via migrations
2. **No manual changes** - Production schema immutable
3. **Baseline brownfield** - Adopt existing databases properly
4. **Document drift** - Investigate and resolve

## Getting Help

- **Documentation**: https://docs.dblift.io
- **Issues**: https://github.com/yourorg/dblift/issues
- **Community**: https://community.dblift.io
- **Examples**: This demo repository!

## Next Steps

- Try the [demo scenarios](../scenarios/)
- Read the [best practices](BEST_PRACTICES.md) guide
- Set up [CI/CD integration](CI_CD_GUIDE.md)
- Configure [validation rules](VALIDATION_GUIDE.md)


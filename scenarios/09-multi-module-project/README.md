# Scenario 09: Multi-Module Project

## Objective
Manage migrations across multiple modules in a monorepo or large project.

## Prerequisites
- DBLift installed
- Understanding of project structure
- Database running

## Problem Statement

Large projects often have:
- Multiple teams working on different modules
- Separate migration directories per module
- Need to deploy all or specific modules
- Complex dependencies between modules

## Project Structure

```
dblift-demo/
├── migrations/
│   ├── core/           # Core schema (required)
│   ├── features/       # Feature modules
│   ├── performance/    # Performance optimizations
│   ├── security/       # Security enhancements
│   └── repeatable/     # Repeatable migrations
├── modules/
│   ├── inventory/
│   │   └── migrations/
│   ├── crm/
│   │   └── migrations/
│   └── analytics/
│       └── migrations/
```

## Steps

### 1. Configure Multi-Directory Support

Update `config/dblift-postgresql.yaml`:

```yaml
database:
  url: "jdbc:postgresql://localhost:5432/dblift_demo"
  schema: "public"
  username: "dblift_user"
  password: "dblift_pass"

migrations:
  # Primary migration directory
  directory: "./migrations/core"
  
  # Additional directories (applied in order)
  directories:
    - "./migrations/features"
    - "./migrations/performance"
    - "./migrations/security"
    - "./modules/inventory/migrations"
    - "./modules/crm/migrations"
    - "./modules/analytics/migrations"
  
  # Scan recursively
  recursive: true
  
  # Encoding
  script_encoding: "utf-8"

logging:
  level: INFO
  
log_format: "text,json,html"
log_dir: "./logs"
```

### 2. Create Module-Specific Migrations

**Inventory Module:**
```sql
-- modules/inventory/migrations/V3_0_0__Create_inventory_schema[inventory].sql
CREATE TABLE inventory_items (
    id SERIAL PRIMARY KEY,
    product_id INTEGER NOT NULL REFERENCES products(id),
    warehouse_location VARCHAR(100),
    quantity INTEGER NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by VARCHAR(50) DEFAULT 'system' NOT NULL
);

CREATE INDEX idx_inventory_product ON inventory_items(product_id);
COMMENT ON TABLE inventory_items IS 'Inventory tracking by location';
```

**CRM Module:**
```sql
-- modules/crm/migrations/V3_1_0__Create_crm_schema[crm].sql
CREATE TABLE crm_contacts (
    id SERIAL PRIMARY KEY,
    customer_id INTEGER REFERENCES customers(id),
    contact_type VARCHAR(50),
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by VARCHAR(50) DEFAULT 'system' NOT NULL
);

COMMENT ON TABLE crm_contacts IS 'CRM contact management';
```

### 3. Deploy All Modules

```bash
dblift migrate --config config/dblift-postgresql.yaml
```

This applies migrations from all configured directories in order.

### 4. Deploy Specific Module

```bash
# Deploy only inventory module
dblift migrate \
  --config config/dblift-postgresql.yaml \
  --tags inventory

# Deploy only CRM module
dblift migrate \
  --config config/dblift-postgresql.yaml \
  --tags crm
```

### 5. Create Module-Specific Configs

**Inventory Module Config:**
```yaml
# config/dblift-inventory.yaml
database:
  url: "jdbc:postgresql://localhost:5432/dblift_demo"
  schema: "public"
  username: "dblift_user"
  password: "dblift_pass"

migrations:
  directory: "./modules/inventory/migrations"
  recursive: true

logging:
  level: INFO
```

Deploy inventory independently:
```bash
dblift migrate --config config/dblift-inventory.yaml
```

### 6. Module Dependencies

Handle dependencies with version ordering:

```
V3_0_0__Create_inventory_schema[inventory].sql    # Base inventory
V3_0_1__Add_inventory_triggers[inventory].sql     # Depends on 3.0.0
V3_1_0__Create_crm_schema[crm].sql               # Depends on customers
V3_2_0__Link_crm_inventory[crm,inventory].sql    # Depends on both
```

### 7. Check Module Status

View status of specific module:
```bash
dblift info \
  --config config/dblift-postgresql.yaml \
  --tags inventory
```

View all modules:
```bash
dblift info --config config/dblift-postgresql.yaml --verbose
```

### 8. Module-Specific Validation

Validate inventory module migrations:
```bash
dblift validate-sql modules/inventory/migrations/ \
  --dialect postgresql \
  --rules-file config/.dblift_rules.yaml
```

## Advanced Patterns

### Pattern 1: Core + Optional Modules

```yaml
# config/dblift-core.yaml
migrations:
  directory: "./migrations/core"

# config/dblift-full.yaml
migrations:
  directory: "./migrations/core"
  directories:
    - "./modules/inventory/migrations"
    - "./modules/crm/migrations"
    - "./modules/analytics/migrations"
```

Deploy core only in small installations:
```bash
dblift migrate --config config/dblift-core.yaml
```

Deploy everything in enterprise:
```bash
dblift migrate --config config/dblift-full.yaml
```

### Pattern 2: Team-Based Directories

Organize by team:

```
migrations/
├── team-platform/migrations/
├── team-payments/migrations/
├── team-shipping/migrations/
└── team-analytics/migrations/
```

Each team manages their own directory with tags:
```sql
-- team-payments/migrations/V4_0_0__Add_payment_gateway[payments,team-payments].sql
```

### Pattern 3: Customer-Specific Modules

For multi-tenant with customer customizations:

```
migrations/
├── core/                    # All customers
├── modules/
│   ├── customer-acme/       # ACME-specific
│   └── customer-globex/     # Globex-specific
```

Deploy per customer:
```bash
# For ACME deployment
dblift migrate --tags customer-acme

# For Globex deployment
dblift migrate --tags customer-globex
```

### Pattern 4: Environment-Specific Modules

```
migrations/
├── core/              # All environments
├── dev-only/          # Development helpers
├── staging-only/      # Staging test data
└── prod-only/         # Production optimizations
```

Configuration per environment:
```yaml
# dev
directories:
  - "./migrations/core"
  - "./migrations/dev-only"

# production
directories:
  - "./migrations/core"
  - "./migrations/prod-only"
```

## CI/CD Integration

### Module-Based Deployment Pipeline

```yaml
# .github/workflows/deploy-modules.yml
name: Deploy Modules

on:
  push:
    paths:
      - 'modules/*/migrations/**'

jobs:
  detect-changes:
    runs-on: ubuntu-latest
    outputs:
      inventory: ${{ steps.changes.outputs.inventory }}
      crm: ${{ steps.changes.outputs.crm }}
      analytics: ${{ steps.changes.outputs.analytics }}
    steps:
      - uses: actions/checkout@v4
      - uses: dorny/paths-filter@v2
        id: changes
        with:
          filters: |
            inventory:
              - 'modules/inventory/migrations/**'
            crm:
              - 'modules/crm/migrations/**'
            analytics:
              - 'modules/analytics/migrations/**'

  deploy-inventory:
    needs: detect-changes
    if: needs.detect-changes.outputs.inventory == 'true'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Deploy inventory
        run: dblift migrate --tags inventory

  deploy-crm:
    needs: detect-changes
    if: needs.detect-changes.outputs.crm == 'true'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Deploy CRM
        run: dblift migrate --tags crm
```

## Best Practices

### 1. Version Ranges by Module

Organize version numbers:
- `1.x.x` - Core schema
- `2.x.x` - Features
- `3.x.x` - Inventory module
- `4.x.x` - CRM module
- `5.x.x` - Analytics module

### 2. Module Documentation

Create `modules/inventory/README.md`:
```markdown
# Inventory Module

## Dependencies
- Core schema (V1.0.0+)
- Products table

## Migrations
- V3.0.0: Initial schema
- V3.0.1: Add triggers
- V3.0.2: Add indexes

## Tags
- inventory
```

### 3. Dependency Validation

Check dependencies before deployment:
```bash
# Ensure core is applied first
dblift info --config config-core.yaml

# Then deploy module
dblift migrate --tags inventory
```

### 4. Module Testing

Test modules independently:
```bash
# Test core
dblift validate --config config-core.yaml

# Test inventory module
dblift validate-sql modules/inventory/migrations/
```

## Troubleshooting

**Q: Migrations applying in wrong order across modules?**
A: Use version numbers to control order (V3.0.0, V3.1.0, etc.)

**Q: Module dependency not satisfied?**
A: Ensure dependent modules have appropriate version numbers

**Q: How to remove a module?**
A: Create undo migrations or use target version to roll back

## Key Takeaways
- Multi-directory support for large projects
- Module-based organization
- Tag-based selective deployment
- Team independence with shared core
- Customer-specific customizations
- Environment-specific migrations
- CI/CD integration per module
- Clear dependency management

## Checklist

- [ ] Define module structure
- [ ] Configure multi-directory in config
- [ ] Assign version ranges to modules
- [ ] Tag all module migrations
- [ ] Document module dependencies
- [ ] Create module-specific configs (optional)
- [ ] Set up CI/CD for changed modules
- [ ] Test module deployment independently
- [ ] Test full deployment
- [ ] Document module ownership

## Resources

- [DBLift Multi-Directory Docs](https://docs.dblift.io/multi-directory)
- [Module Organization Best Practices](https://docs.dblift.io/best-practices/modules)

## Conclusion

You've completed all 9 demo scenarios! You now understand:
- Basic migrations
- Validation rules
- Rollback and recovery
- Multi-environment deployment
- Drift detection
- CI/CD integration
- Tag-based deployment
- Brownfield migration
- Multi-module projects

Continue exploring the [documentation](../../docs/) for more advanced topics!


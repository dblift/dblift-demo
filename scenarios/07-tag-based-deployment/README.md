# Scenario 07: Tag-Based Deployment

## Objective
Demonstrate selective migration execution using tags for feature-based deployments.

## Prerequisites
- DBLift installed
- Understanding of migration naming conventions
- Database running

## Migration Tags

Migrations can include tags in square brackets:
```
V1_1_0__Add_user_preferences[user-mgmt].sql
V1_1_1__Add_notifications[notifications].sql
V1_2_0__Add_analytics[analytics].sql
V2_0_0__Add_audit_tables[security].sql
```

## Steps

### 1. Review Tagged Migrations

List all migrations with tags:
```bash
grep -r "\[.*\]\.sql" migrations/
```

Output:
```
migrations/features/V1_1_0__Add_user_preferences[user-mgmt].sql
migrations/features/V1_1_1__Add_notifications[notifications].sql
migrations/features/V1_2_0__Add_analytics[analytics].sql
migrations/security/V2_0_0__Add_audit_tables[security].sql
migrations/security/V2_0_1__Add_encryption[security].sql
```

### 2. Deploy Core Migrations Only

Deploy base schema without any tagged features:
```bash
dblift migrate \
  --config config/dblift-postgresql.yaml \
  --exclude-tags user-mgmt,notifications,analytics,security
```

This will apply:
- V1_0_0__Initial_schema.sql
- V1_0_1__Add_customers.sql
- V1_0_2__Add_products.sql
- V1_0_3__Add_orders.sql

### 3. Deploy User Management Features

```bash
dblift migrate \
  --config config/dblift-postgresql.yaml \
  --tags user-mgmt
```

This applies only migrations tagged with `[user-mgmt]`.

### 4. Deploy Multiple Feature Sets

Deploy user management and notifications together:
```bash
dblift migrate \
  --config config/dblift-postgresql.yaml \
  --tags user-mgmt,notifications
```

### 5. Check Status by Tag

View which migrations are applied for a specific tag:
```bash
dblift info \
  --config config/dblift-postgresql.yaml \
  --tags security
```

Output shows only security-tagged migrations.

### 6. Exclude Specific Tags

Deploy everything except analytics:
```bash
dblift migrate \
  --config config/dblift-postgresql.yaml \
  --exclude-tags analytics
```

### 7. Combine Tags and Version Targeting

Deploy user-mgmt features up to version 1.2.0:
```bash
dblift migrate \
  --config config/dblift-postgresql.yaml \
  --tags user-mgmt \
  --target-version 1.2.0
```

### 8. Environment-Specific Tag Deployment

Different environments can have different features:

**Development** (all features):
```bash
dblift migrate --config config/dblift-dev.yaml
```

**Staging** (no analytics yet):
```bash
dblift migrate \
  --config config/dblift-staging.yaml \
  --exclude-tags analytics
```

**Production** (core + user-mgmt only):
```bash
dblift migrate \
  --config config/dblift-prod.yaml \
  --tags user-mgmt
```

## Use Cases

### Feature Flags

Tags can work like feature flags:

```sql
-- migrations/features/V1_5_0__New_beta_feature[beta].sql
CREATE TABLE beta_feature_data (
    -- Beta feature tables
);
```

Deploy to beta testers only:
```bash
dblift migrate --config config.yaml --tags beta
```

### Module-Based Deployments

Organize by business modules:

```
V2_1_0__Add_inventory_tracking[inventory].sql
V2_1_1__Add_inventory_alerts[inventory].sql
V2_2_0__Add_crm_contacts[crm].sql
V2_2_1__Add_crm_opportunities[crm].sql
```

Deploy inventory module:
```bash
dblift migrate --config config.yaml --tags inventory
```

### Customer-Specific Features

For multi-tenant applications:

```
V3_0_0__Add_enterprise_features[enterprise].sql
V3_0_1__Add_advanced_analytics[enterprise].sql
```

Enterprise customers get:
```bash
dblift migrate --config config.yaml --tags enterprise
```

Standard customers don't get enterprise features.

### Compliance and Security

Gradual rollout of security features:

```bash
# Phase 1: Core security
dblift migrate --tags security-core

# Phase 2: Advanced security
dblift migrate --tags security-advanced

# Phase 3: Compliance features
dblift migrate --tags security-compliance
```

## Tag Naming Conventions

**Good tag names:**
- `user-mgmt` - Clear module identifier
- `security` - Broad category
- `analytics-v2` - Versioned feature
- `beta` - Deployment status
- `enterprise` - Customer tier

**Avoid:**
- `temp` - Too vague
- `fix-123` - Too specific
- `johns-feature` - Personal names

## Advanced Patterns

### Multiple Tags Per Migration

```sql
-- V2_0_0__Add_audit_log[security,compliance,enterprise].sql
```

Deploy with any matching tag:
```bash
# This will apply the migration
dblift migrate --tags security

# This will also apply it
dblift migrate --tags enterprise
```

### Tag Inheritance

Organize tags hierarchically in documentation:

```
security
├── security-core
├── security-advanced
└── security-compliance

features
├── user-mgmt
├── notifications
└── analytics
```

### CI/CD Integration

Use tags in deployment pipeline:

```yaml
# .github/workflows/deploy-by-feature.yml
deploy-user-features:
  runs-on: ubuntu-latest
  steps:
    - name: Deploy user features
      run: dblift migrate --tags user-mgmt,notifications

deploy-analytics:
  runs-on: ubuntu-latest
  needs: deploy-user-features
  steps:
    - name: Deploy analytics
      run: dblift migrate --tags analytics
```

## Key Takeaways
- Tags enable selective migration deployment
- Useful for feature flags and A/B testing
- Supports module-based development
- Enables customer-tier differentiation
- Facilitates gradual rollouts
- Integrates well with CI/CD pipelines
- Multiple tags per migration supported

## Best Practices

1. **Consistent naming**: Use lowercase, hyphen-separated
2. **Document tags**: Maintain a TAG_GUIDE.md
3. **Don't over-tag**: Only tag when needed
4. **Version carefully**: Tagged migrations still follow version order
5. **Test thoroughly**: Ensure tag combinations work together

## Troubleshooting

**Q: Migration not applying with tag?**
A: Check if it has multiple tags - you need to specify at least one matching tag.

**Q: Can I change tags after deployment?**
A: No - tags are part of migration filename and tracked in history.

**Q: Do tags affect migration order?**
A: No - migrations always apply in version order, tags only filter which ones run.

## Next Steps
- Try [Scenario 08: Brownfield Migration](../08-brownfield-migration/)


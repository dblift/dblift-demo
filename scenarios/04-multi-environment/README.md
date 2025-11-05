# Scenario 04: Multi-Environment Setup

## Objective
Manage migrations across development, staging, and production environments.

## Prerequisites
- DBLift installed
- Multiple database instances (or use Docker for local demo)

## Steps

### 1. Create Environment-Specific Configs

Create `config/dblift-dev.yaml`:
```yaml
database:
  url: "jdbc:postgresql://localhost:5432/dblift_dev"
  schema: "public"
  username: "dblift_user"
  password: "dblift_pass"

migrations:
  directory: "./migrations/core"
  directories:
    - "./migrations/features"
  
logging:
  level: DEBUG
  
log_format: "text,json,html"
log_dir: "./logs/dev"
```

Create `config/dblift-staging.yaml`:
```yaml
database:
  url: "${STAGING_DB_URL}"
  schema: "public"
  username: "${STAGING_DB_USERNAME}"
  password: "${STAGING_DB_PASSWORD}"

migrations:
  directory: "./migrations/core"
  directories:
    - "./migrations/features"
    - "./migrations/performance"
  
validation:
  enabled: true
  fail_on_violations: true
  
logging:
  level: INFO
  
log_format: "text,json"
log_dir: "./logs/staging"
```

Create `config/dblift-prod.yaml`:
```yaml
database:
  url: "${PROD_DB_URL}"
  schema: "public"
  username: "${PROD_DB_USERNAME}"
  password: "${PROD_DB_PASSWORD}"

migrations:
  directory: "./migrations/core"
  directories:
    - "./migrations/features"
    - "./migrations/performance"
    - "./migrations/security"
  
validation:
  enabled: true
  fail_on_violations: true
  severity_threshold: "error"
  
logging:
  level: WARN
  
log_format: "json,html"
log_dir: "./logs/production"
```

### 2. Start Multiple Databases (Local Demo)

```bash
# Start development database
docker-compose up -d postgres

# Start staging database (on different port)
docker run -d \
  --name dblift-demo-staging \
  -e POSTGRES_DB=dblift_staging \
  -e POSTGRES_USER=dblift_user \
  -e POSTGRES_PASSWORD=dblift_pass \
  -p 5433:5432 \
  postgres:15
```

### 3. Deploy to Development

```bash
dblift migrate --config config/dblift-dev.yaml
```

Check status:
```bash
dblift info --config config/dblift-dev.yaml
```

### 4. Deploy to Staging (with validation)

```bash
# Validate first
dblift validate --config config/dblift-staging.yaml

# Then migrate
export STAGING_DB_URL="jdbc:postgresql://localhost:5433/dblift_staging"
export STAGING_DB_USERNAME="dblift_user"
export STAGING_DB_PASSWORD="dblift_pass"

dblift migrate --config config/dblift-staging.yaml
```

### 5. Deploy to Production (with extra caution)

```bash
# Dry run first
dblift migrate \
  --config config/dblift-prod.yaml \
  --dry-run

# Review the output, then run for real
dblift migrate --config config/dblift-prod.yaml
```

### 6. Environment-Specific Tags

Deploy only specific features to staging:

```bash
# Deploy only user management features
dblift migrate \
  --config config/dblift-staging.yaml \
  --tags user-mgmt,notifications
```

### 7. Check Drift Across Environments

```bash
# Check dev
dblift diff --config config/dblift-dev.yaml

# Check staging  
dblift diff --config config/dblift-staging.yaml

# Check production
dblift diff --config config/dblift-prod.yaml
```

### 8. Compare Environments

Create a comparison script:

```bash
#!/bin/bash
echo "=== Development ==="
dblift info --config config/dblift-dev.yaml --format json > dev-status.json

echo "=== Staging ==="
dblift info --config config/dblift-staging.yaml --format json > staging-status.json

echo "=== Production ==="
dblift info --config config/dblift-prod.yaml --format json > prod-status.json

echo "Comparison complete. Review JSON files."
```

## Key Takeaways
- Separate configs for each environment
- Use environment variables for sensitive data
- Validate before deploying to production
- Use tags for selective deployment
- Different log levels per environment
- Always test in dev/staging before production
- Drift detection across all environments

## Best Practices

1. **Never skip environments**: Dev → Staging → Prod
2. **Use CI/CD**: Automate deployment pipeline
3. **Backup before migration**: Especially production
4. **Monitor drift**: Regular scheduled checks
5. **Tag migrations**: Enable selective deployment
6. **Document exceptions**: Any manual changes

## Next Steps
- Try [Scenario 05: Drift Detection](../05-drift-detection/)


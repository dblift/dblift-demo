# Scenario 06: CI/CD Integration

## Objective
Integrate DBLift into CI/CD pipelines for automated validation and deployment.

## Prerequisites
- DBLift installed
- GitHub repository (or GitLab)
- Basic understanding of GitHub Actions

## GitHub Actions Integration

### 1. Review Existing Workflows

The demo repository includes several GitHub Actions workflows:

```bash
ls -la .github/workflows/
```

You should see:
- `validate-sql.yml` - SQL validation on PRs
- `migrate-dev.yml` - Auto-deploy to dev
- `migrate-prod.yml` - Production deployment
- `drift-detection.yml` - Scheduled drift detection

### 2. SQL Validation on Pull Requests

Review the validation workflow:
```bash
cat .github/workflows/validate-sql.yml
```

**Key features:**
- Runs on every PR with SQL changes
- Validates syntax and business rules
- Generates SARIF report for GitHub Code Scanning
- Provides inline PR annotations

**To test:**
1. Create a new branch
2. Add a migration with violations
3. Create a pull request
4. Watch the validation run

### 3. Configure GitHub Secrets

Set up secrets for database connections:

```bash
# Go to: Repository Settings → Secrets and variables → Actions

# Add secrets:
DEV_DB_URL=jdbc:postgresql://dev-server:5432/db
DEV_DB_USERNAME=dbuser
DEV_DB_PASSWORD=securepass

STAGING_DB_URL=jdbc:postgresql://staging-server:5432/db
STAGING_DB_USERNAME=dbuser
STAGING_DB_PASSWORD=securepass

PROD_DB_URL=jdbc:postgresql://prod-server:5432/db
PROD_DB_USERNAME=dbuser
PROD_DB_PASSWORD=securepass
```

### 4. Automated Development Deployment

Review the dev deployment workflow:
```bash
cat .github/workflows/migrate-dev.yml
```

**Workflow:**
1. Triggered on push to `develop` branch
2. Downloads DBLift binary
3. Validates migrations
4. Runs migrations on dev database
5. Checks for drift
6. Uploads logs as artifacts

**To test:**
```bash
git checkout -b develop
git add migrations/
git commit -m "Add new migration"
git push origin develop
```

### 5. Production Deployment Workflow

Review the production workflow:
```bash
cat .github/workflows/migrate-prod.yml
```

**Key features:**
- Manual approval required (environment protection)
- Dry-run validation
- Creates issues on failure
- Retains logs for 90 days

**To enable:**
1. Go to: Repository Settings → Environments
2. Create "production" environment
3. Add required reviewers
4. Set deployment branch restrictions

### 6. Drift Detection Automation

Review the drift detection workflow:
```bash
cat .github/workflows/drift-detection.yml
```

**Features:**
- Runs daily via cron schedule
- Checks all environments (dev, staging, prod)
- Creates GitHub issues on drift detection
- Uploads drift reports as artifacts

**Manual trigger:**
```bash
# Go to: Actions tab → Schema Drift Detection → Run workflow
```

### 7. SARIF Integration for Code Scanning

The validation workflow generates SARIF (Static Analysis Results Interchange Format):

```yaml
- name: Generate SARIF report
  run: |
    dblift validate-sql migrations/ \
      --dialect postgresql \
      --format sarif \
      --output validation-results.sarif

- name: Upload SARIF
  uses: github/codeql-action/upload-sarif@v3
  with:
    sarif_file: validation-results.sarif
```

**Benefits:**
- Violations appear in "Security" tab
- Inline annotations on PR files
- Trends and metrics dashboard

### 8. Pre-commit Hooks (Local Validation)

Create `.pre-commit-config.yaml`:
```yaml
repos:
  - repo: local
    hooks:
      - id: validate-sql
        name: Validate SQL migrations
        entry: dblift validate-sql migrations/
        language: system
        pass_filenames: false
        args:
          - --dialect
          - postgresql
          - --rules-file
          - config/.dblift_rules.yaml
```

Install pre-commit:
```bash
pip install pre-commit
pre-commit install
```

Now validation runs automatically before each commit.

## GitLab CI Integration

Create `.gitlab-ci.yml`:
```yaml
stages:
  - validate
  - deploy-dev
  - deploy-staging
  - deploy-prod

validate-sql:
  stage: validate
  image: alpine:latest
  before_script:
    - apk add --no-cache curl tar
    - curl -L -o dblift.tar.gz https://github.com/dblift/dblift/releases/latest/download/dblift-linux-x64.tar.gz
    - tar xzf dblift.tar.gz
  script:
    - ./dblift-linux-x64/dblift validate-sql migrations/ --dialect postgresql --rules-file config/.dblift_rules.yaml
  only:
    - merge_requests
    - main

deploy-dev:
  stage: deploy-dev
  image: alpine:latest
  before_script:
    - apk add --no-cache curl tar
    - curl -L -o dblift.tar.gz https://github.com/dblift/dblift/releases/latest/download/dblift-linux-x64.tar.gz
    - tar xzf dblift.tar.gz
  script:
    - ./dblift-linux-x64/dblift migrate --config config/dblift-dev.yaml
  environment:
    name: development
  only:
    - develop

deploy-staging:
  stage: deploy-staging
  image: alpine:latest
  before_script:
    - apk add --no-cache curl tar
    - curl -L -o dblift.tar.gz https://github.com/dblift/dblift/releases/latest/download/dblift-linux-x64.tar.gz
    - tar xzf dblift.tar.gz
  script:
    - ./dblift-linux-x64/dblift migrate --config config/dblift-staging.yaml
  environment:
    name: staging
  when: manual
  only:
    - main

deploy-prod:
  stage: deploy-prod
  image: alpine:latest
  before_script:
    - apk add --no-cache curl tar
    - curl -L -o dblift.tar.gz https://github.com/dblift/dblift/releases/latest/download/dblift-linux-x64.tar.gz
    - tar xzf dblift.tar.gz
  script:
    - ./dblift-linux-x64/dblift migrate --config config/dblift-prod.yaml
  environment:
    name: production
  when: manual
  only:
    - main
```

## Best Practices

### 1. Validation Gates
```yaml
# Block merges on validation failure
- name: Validate
  run: dblift validate-sql migrations/ --fail-on-violations
```

### 2. Artifact Retention
```yaml
# Keep production logs longer
- uses: actions/upload-artifact@v4
  with:
    name: prod-logs
    path: logs/
    retention-days: 90
```

### 3. Notifications
```yaml
# Slack notification on failure
- name: Notify Slack
  if: failure()
  uses: slackapi/slack-github-action@v1
  with:
    webhook-url: ${{ secrets.SLACK_WEBHOOK }}
```

### 4. Deployment Protection
- Require PR reviews for main branch
- Use environment protection rules
- Implement manual approval gates
- Restrict who can deploy to production

### 5. Rollback Strategy
```yaml
# Automatic rollback on failure
- name: Rollback on failure
  if: failure()
  run: dblift undo --target-version $PREVIOUS_VERSION
```

## Key Takeaways
- Automate SQL validation in PR process
- Progressive deployment (dev → staging → prod)
- Scheduled drift detection
- SARIF integration for security scanning
- Pre-commit hooks for local validation
- Comprehensive logging and artifacts
- Manual approval for production
- Notification on failures

## Next Steps
- Try [Scenario 07: Tag-Based Deployment](../07-tag-based-deployment/)


# GitHub Actions Workflows

⚠️ **IMPORTANT**: These workflows require Docker images to be published first!

## Prerequisites

Before enabling these workflows, you must:

1. **Publish Docker images** to GitHub Container Registry:
   ```bash
   cd /path/to/dblift  # Main repository
   ./scripts/publish_all_docker_images.sh
   ```

2. **Make images public**:
   - Go to: https://github.com/users/cmodiano/packages
   - Change visibility of both packages to "Public"

3. **Verify images are accessible**:
   ```bash
   docker pull ghcr.io/cmodiano/dblift:latest
   docker pull ghcr.io/cmodiano/dblift-validation:latest
   ```

## Workflows Overview

### 1. validate-sql.yml
- **Trigger**: On every PR with SQL changes
- **Image**: `ghcr.io/cmodiano/dblift-validation:latest` (250MB)
- **Purpose**: Validate SQL syntax and business rules

### 2. migrate-dev.yml
- **Trigger**: Push to `develop` branch OR manual
- **Image**: `ghcr.io/cmodiano/dblift:latest` (691MB)
- **Purpose**: Deploy to development database

### 3. migrate-prod.yml
- **Trigger**: Push to `main` branch OR manual
- **Image**: `ghcr.io/cmodiano/dblift:latest` (691MB)
- **Purpose**: Deploy to production database
- **Creates GitHub issue on failure**

### 4. drift-detection.yml
- **Trigger**: Daily at 9 AM UTC OR manual
- **Image**: `ghcr.io/cmodiano/dblift:latest` (691MB)
- **Purpose**: Detect schema drift across all environments
- **Creates GitHub issue if drift detected**

## Required Secrets

Configure these in your repository settings (Settings → Secrets and variables → Actions):

### Development
- `DEV_DB_URL`
- `DEV_DB_USERNAME`
- `DEV_DB_PASSWORD`

### Staging (for drift detection)
- `STAGING_DB_URL`
- `STAGING_DB_USERNAME`
- `STAGING_DB_PASSWORD`

### Production
- `PROD_DB_URL`
- `PROD_DB_USERNAME`
- `PROD_DB_PASSWORD`

## Enabling Manual Triggers

All workflows support manual triggering via `workflow_dispatch`. 

To run manually:
1. Go to: Actions tab
2. Select workflow
3. Click "Run workflow" button
4. Choose branch
5. Click "Run workflow"

## Troubleshooting

### "Unable to find image" or "unauthorized"
- **Cause**: Images not published yet or not public
- **Fix**: Follow prerequisites above

### "403 permission_denied"
- **Cause**: Missing `issues: write` permission
- **Fix**: Already added to workflows that need it

### "Resource not accessible by integration"
- **Cause**: Workflow trying to create issues without permission
- **Fix**: Already added `permissions: issues: write`

## Status

- ✅ All workflows updated to use Docker
- ✅ All permissions configured correctly
- ✅ Manual triggers available
- ⏳ Waiting for Docker images to be published


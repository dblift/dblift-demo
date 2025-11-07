# GitHub Actions Workflows

## Scenario Walkthrough Workflows

Each demo scenario now has a dedicated workflow that runs the scripted walkthrough and publishes a step-by-step summary plus detailed artifacts.

| Scenario | Workflow file | Highlights |
|----------|---------------|------------|
| 01 - Basic Migration | `scenario-01-basic-migration.yml` | Applies baseline migrations, shows before/after status |
| 02 - Validation Rules | `scenario-02-validation-rules.yml` | Demonstrates failing vs. passing validation runs |
| 03 - Rollback & Recovery | `scenario-03-rollback-recovery.yml` | Executes undo, simulates corruption, repairs history |
| 04 - Drift Detection | `scenario-04-drift-detection.yml` | Simulates drift and generates HTML/JSON reports |
| 05 - CI/CD Integration | `scenario-05-ci-cd-integration.yml` | Surfaces workflow catalog and produces SARIF output |
| 06 - Tag-Based Deployment | `scenario-06-tag-based-deployment.yml` | Runs selective migration waves using tags |
| 07 - Brownfield Migration | `scenario-07-brownfield-migration.yml` | Baselines legacy schema then layers new changes |
| 08 - Multi-Module Project | `scenario-08-multi-module.yml` | Manages module directories and module-scoped validation |

Trigger any scenario from the Actions tab via **Run workflow** to see a narrated execution in the job summary and downloadable logs under `scenario-<id>-logs`.

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

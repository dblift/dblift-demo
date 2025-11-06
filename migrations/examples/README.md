# Example Migrations for CI/CD Demo

This directory contains example migrations that demonstrate the PR validation workflow.

## Files

### V9_0_0__Example_bad_migration.sql
❌ **Intentionally contains validation errors** for demonstration purposes.

**Violations:**
- Missing primary key
- Missing audit columns
- Uses SELECT *
- DELETE without WHERE clause
- Poor table naming

**Purpose:** Use this to test the CI/CD validation workflow and see how errors are reported.

### V9_0_1__Example_good_migration.sql
✅ **Follows all validation rules** and best practices.

**Features:**
- Primary key defined
- Audit columns included
- Table comments
- Proper naming conventions
- Explicit column lists
- WHERE clauses on DELETE

**Purpose:** Use this as a template for proper migrations.

## Testing the CI/CD Workflow

1. Create a branch with the bad migration:
   ```bash
   git checkout -b test-bad-migration
   git add migrations/examples/V9_0_0__Example_bad_migration.sql
   git commit -m "Add migration with violations for testing"
   git push origin test-bad-migration
   ```

2. Create a Pull Request

3. Watch the workflow:
   - GitHub Actions runs validation
   - Inline annotations appear on the code
   - SARIF report uploaded to Security tab
   - PR comment shows summary
   - Merge is blocked due to errors

4. Fix by using the good migration instead:
   ```bash
   git rm migrations/examples/V9_0_0__Example_bad_migration.sql
   git add migrations/examples/V9_0_1__Example_good_migration.sql
   git commit -m "Fix validation errors"
   git push
   ```

5. Workflow re-runs and passes ✅

## See Also

- [CI/CD Validation Demo Guide](../../docs/CI_CD_VALIDATION_DEMO.md)
- [Validation Rules](../../config/.dblift_rules.yaml)
- [Scenario 06: CI/CD Integration](../../scenarios/06-ci-cd-integration/)


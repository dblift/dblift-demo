# CI/CD Validation Demo Guide

This guide demonstrates how DBLift's validation workflow works in GitHub Actions during Pull Requests.

## Overview

When you create a PR with SQL migrations, the validation workflow:

1. ✅ **Detects changed SQL files**
2. ✅ **Validates syntax and business rules**
3. ✅ **Creates inline annotations** on problematic code
4. ✅ **Generates SARIF report** for GitHub Code Scanning
5. ✅ **Posts PR comment** with summary
6. ✅ **Blocks merge** if critical errors found

## Workflow Features

### 1. Automatic Detection

The workflow triggers on any PR that modifies:
- `migrations/**/*.sql` files
- `config/.dblift_rules.yaml` validation rules

### 2. Inline Annotations

Validation errors appear directly in the PR diff view:

```
migrations/V9_0_0__Example_bad.sql
Line 5: ❌ Table 'bad_example_table' must have a primary key [require_primary_key]
Line 5: ❌ Tables must have audit columns (created_at, updated_at, created_by) [require_audit_columns]
Line 12: ⚠️ Avoid SELECT * - explicitly list required columns [no_select_star]
```

### 3. SARIF Integration

SARIF (Static Analysis Results Interchange Format) enables:
- Results in GitHub Security tab
- Trend analysis over time
- Integration with GitHub Advanced Security
- Export to other tools

### 4. PR Comment Summary

A detailed comment is posted with:
- **Summary table** of errors/warnings/info
- **List of all issues** with file locations
- **Links** to security tab and validation rules
- **Action required** if errors block merge

## Example PR Comment

```markdown
## ❌ SQL Validation Results

**Status:** ❌ 3 error(s) found

| Severity | Count |
|----------|-------|
| Errors   | 3     |
| Warnings | 1     |
| Info     | 0     |

### Issues Found

❌ **require_primary_key** (Line 5)
📄 `migrations/examples/V9_0_0__Example_bad.sql`
> Table 'bad_example_table' must have a primary key

❌ **require_audit_columns** (Line 5)
📄 `migrations/examples/V9_0_0__Example_bad.sql`
> Tables must have audit columns (created_at, updated_at, created_by)

⚠️ **no_select_star** (Line 12)
📄 `migrations/examples/V9_0_0__Example_bad.sql`
> Avoid SELECT * - explicitly list required columns

---
💡 **Tip:** Check the Security tab for detailed SARIF analysis.
📖 Review our validation rules for more information.
```

## Try It Yourself

### Step 1: Create a Branch with a Bad Migration

```bash
cd dblift-demo
git checkout -b test-validation

# Add a migration with violations
cat > migrations/test/V99_0_0__test_bad.sql << 'EOF'
-- Bad migration for testing
CREATE TABLE test_table (
    name VARCHAR(100)
);
EOF

git add migrations/test/
git commit -m "Add test migration with violations"
git push origin test-validation
```

### Step 2: Create a Pull Request

1. Go to: https://github.com/dblift/dblift-demo
2. Click "Pull requests" → "New pull request"
3. Select your branch
4. Create the PR

### Step 3: Watch the Validation

The workflow will:
- ✅ Run automatically
- ⚠️ Find violations
- 📝 Post comment with results
- ❌ Block merge if errors found

### Step 4: Fix the Issues

```bash
# Update the migration
cat > migrations/test/V99_0_0__test_bad.sql << 'EOF'
-- Fixed migration
CREATE TABLE test_table (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by VARCHAR(50) DEFAULT 'system' NOT NULL
);

COMMENT ON TABLE test_table IS 'Test table';
EOF

git add migrations/test/
git commit -m "Fix validation errors"
git push
```

### Step 5: Re-run Validation

The workflow runs again and:
- ✅ Finds no errors
- ✅ Posts success comment
- ✅ Allows merge

## Validation Rules Demonstrated

### Critical (Error - Blocks Merge)

| Rule | Description |
|------|-------------|
| `require_primary_key` | All tables must have PRIMARY KEY |
| `require_audit_columns` | Tables need created_at, updated_at, created_by |
| `no_drop_table` | DROP TABLE not allowed in migrations |
| `require_where_in_delete` | DELETE must have WHERE clause |
| `require_where_in_update` | UPDATE must have WHERE clause |

### Important (Warning - Allowed but Flagged)

| Rule | Description |
|------|-------------|
| `table_naming_snake_case` | Tables must be lowercase_snake_case |
| `column_naming_lowercase` | Columns must be lowercase |
| `fk_requires_index` | Foreign keys should have indexes |

### Informational (Info - Best Practice)

| Rule | Description |
|------|-------------|
| `no_select_star` | Avoid SELECT *, list columns explicitly |
| `require_table_comments` | Tables should have documentation |

## SARIF Report Structure

The SARIF report includes:

```json
{
  "$schema": "https://raw.githubusercontent.com/oasis-tcs/sarif-spec/master/Schemata/sarif-schema-2.1.0.json",
  "version": "2.1.0",
  "runs": [{
    "tool": {
      "driver": {
        "name": "DBLift SQL Validator",
        "version": "0.4.0"
      }
    },
    "results": [{
      "ruleId": "require_primary_key",
      "level": "error",
      "message": {
        "text": "Table must have a primary key"
      },
      "locations": [{
        "physicalLocation": {
          "artifactLocation": {
            "uri": "migrations/V9_0_0__Bad.sql"
          },
          "region": {
            "startLine": 5,
            "startColumn": 1
          }
        }
      }]
    }]
  }]
}
```

## GitHub Security Integration

After SARIF upload, view results in:

1. **Security Tab**
   - Navigate to: Repository → Security → Code scanning alerts
   - Filter by tool: "DBLift SQL Validator"
   - See all issues with severity

2. **PR Checks**
   - View in PR "Checks" tab
   - See all annotations inline
   - Click for details

3. **Trends Over Time**
   - Track validation issues across PRs
   - Measure code quality improvements
   - Identify common mistakes

## Customizing Validation

### Add Custom Rules

Edit `config/.dblift_rules.yaml`:

```yaml
rules:
  - name: company_specific_rule
    type: pattern
    regex: "-- Approved by: [A-Z][a-z]+ [A-Z][a-z]+"
    message: "All migrations must have approval comment"
    severity: error
```

### Adjust Severity Levels

```yaml
validation:
  fail_on_violations: true
  severity_threshold: "warning"  # Change to "error" to allow warnings
```

### Exclude Specific Files

```yaml
# In workflow
- name: Validate
  run: |
    dblift validate-sql migrations/ \
      --exclude 'migrations/legacy/*' \
      --exclude 'migrations/archive/*'
```

## Best Practices

### 1. Run Validation Locally Before Pushing

```bash
# Install DBLift
pip install dblift

# Validate migrations
dblift validate-sql migrations/ \
  --dialect postgresql \
  --rules-file config/.dblift_rules.yaml
```

### 2. Use Pre-commit Hooks

```yaml
# .pre-commit-config.yaml
repos:
  - repo: local
    hooks:
      - id: validate-sql
        name: Validate SQL
        entry: dblift validate-sql migrations/
        language: system
        pass_filenames: false
```

### 3. Review Validation Results

- Fix errors immediately
- Consider warnings carefully
- Document any exceptions

### 4. Keep Rules Updated

- Review validation rules quarterly
- Add rules based on production issues
- Get team consensus on new rules

## Troubleshooting

### Workflow Not Triggering

**Check:**
- PR modifies files in `migrations/**/*.sql`
- Workflow file is in `.github/workflows/`
- GitHub Actions is enabled

### Annotations Not Showing

**Check:**
- SARIF format is valid
- `security-events: write` permission granted
- Using `github/codeql-action/upload-sarif@v3`

### False Positives

**Solution:**
- Update validation rules
- Add exceptions for specific cases
- Use `--exclude` patterns

## Resources

- [GitHub SARIF Documentation](https://docs.github.com/en/code-security/code-scanning/integrating-with-code-scanning/sarif-support-for-code-scanning)
- [GitHub Actions Annotations](https://docs.github.com/en/actions/using-workflows/workflow-commands-for-github-actions#setting-an-error-message)
- [DBLift Validation Rules](../config/.dblift_rules.yaml)
- [Example Workflows](.github/workflows/)

## Next Steps

1. ✅ Try creating a test PR with violations
2. ✅ Review SARIF output in Security tab
3. ✅ Customize validation rules for your team
4. ✅ Add to your development workflow

---

**Questions?** Open an issue or check the [scenarios guide](../scenarios/06-ci-cd-integration/).


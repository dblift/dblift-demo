# DBLift Demo Repository

> **Important**: This repository demonstrates how to USE DBLift for database migrations.
> It does NOT contain DBLift source code. See [Installation](#installation) for how to get DBLift.

## Quick Start (5 Minutes)

### 1. Install DBLift

**Option A: Docker (Easiest)**
```bash
docker pull ghcr.io/dblift/dblift:latest
alias dblift='docker run --rm -v $(pwd):/workspace ghcr.io/dblift/dblift:latest'
```

**Option B: Download Binary**
```bash
# Linux
curl -L -o dblift-linux-x64.tar.gz \
  https://github.com/dblift/dblift/releases/latest/download/dblift-linux-x64.tar.gz
tar xzf dblift-linux-x64.tar.gz
export PATH="$PATH:$(pwd)/dblift-linux-x64"
```

See [INSTALL.md](INSTALL.md) for detailed instructions.

### 2. Start Database
```bash
docker-compose up -d postgres
```

### 3. Run Migrations
```bash
dblift migrate --config config/dblift-postgresql.yaml
```

### 4. View Status
```bash
dblift info --config config/dblift-postgresql.yaml
```

Done! ??

## What's Included

- ? **Migration Examples** - Versioned, repeatable, and undo migrations
- ? **Validation Rules** - Custom SQL validation with business rules
- ? **CI/CD Examples** - GitHub Actions workflows
- ? **Multi-Database Support** - PostgreSQL, SQL Server, MySQL
- ? **9 Demo Scenarios** - Step-by-step walkthroughs
- ? **Configuration Examples** - Production-ready configs

## Demo Scenarios

| # | Scenario | Description | Time |
|---|----------|-------------|------|
| 01 | [Basic Migration](scenarios/01-basic-migration/) | Getting started | 10 min |
| 02 | [Validation Rules](scenarios/02-validation-rules/) | SQL quality checks | 15 min |
| 03 | [Rollback & Recovery](scenarios/03-rollback-recovery/) | Undo migrations | 15 min |
| 04 | [Multi-Environment](scenarios/04-multi-environment/) | Dev/staging/prod | 20 min |
| 05 | [Drift Detection](scenarios/05-drift-detection/) | Schema monitoring | 15 min |
| 06 | [CI/CD Integration](scenarios/06-ci-cd-integration/) | Automation | 20 min |
| 07 | [Tag-Based Deployment](scenarios/07-tag-based-deployment/) | Selective rollout | 15 min |
| 08 | [Brownfield Migration](scenarios/08-brownfield-migration/) | Existing databases | 20 min |
| 09 | [Multi-Module Project](scenarios/09-multi-module-project/) | Large projects | 15 min |

## Repository Structure

```
dblift-demo/
??? migrations/           # SQL migration examples
?   ??? core/            # Core schema
?   ??? features/        # Feature-specific
?   ??? performance/     # Optimizations
?   ??? security/        # Security enhancements
??? config/              # Configuration files
??? scenarios/           # Demo walkthroughs
??? .github/workflows/   # CI/CD examples
??? sample-data/         # Sample data scripts
??? docs/               # Documentation

# NOT INCLUDED:
# ? DBLift source code (private repository)
# ? DBLift binaries (download separately)
```

## Features Demonstrated

### Migration Types
- Versioned migrations (V) - Sequential changes
- Repeatable migrations (R) - Views, functions, procedures
- Undo migrations (U) - Rollback capability

### Validation & Quality
- SQL syntax validation
- Business rules enforcement
- Performance analysis
- Naming convention checks

### Operations
- Schema drift detection
- Multi-format logging (TEXT, JSON, HTML)
- Tag-based deployment
- Multi-environment management

## Installation

See [INSTALL.md](INSTALL.md) for detailed installation instructions.

## Documentation

- [Installation Guide](INSTALL.md)
- [Features Overview](docs/FEATURES.md)
- [Validation Guide](docs/VALIDATION_GUIDE.md)
- [CI/CD Guide](docs/CI_CD_GUIDE.md)
- [Best Practices](docs/BEST_PRACTICES.md)
- [Troubleshooting](docs/TROUBLESHOOTING.md)

## Getting DBLift

- **Releases**: https://github.com/dblift/dblift/releases
- **Docker**: `ghcr.io/dblift/dblift:latest`
- **Documentation**: https://github.com/dblift/dblift
- **Issues**: https://github.com/dblift/dblift/issues

## Support

- Documentation: https://docs.dblift.io
- Community: https://community.dblift.io
- Issues: https://github.com/dblift/dblift/issues
- Email: support@dblift.io

## Contributing

This is a demo repository showing how to use DBLift.

To contribute to DBLift itself or report issues:
- Main repository: https://github.com/dblift/dblift
- Issues: https://github.com/dblift/dblift/issues

## License

Demo content: MIT License
DBLift: See main repository for license

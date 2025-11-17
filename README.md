# DBLift Demo Repository

> **Important**: This repository demonstrates how to USE DBLift for database migrations.
> It does NOT contain DBLift source code. See [Installation](#installation) for how to get DBLift.

## 🚀 Try It Now - Interactive Demo

**Want to see DBLift in action?** Choose your preferred method:

### ⚡ Fastest: GitHub Codespace (Recommended)
[![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/dblift/dblift-demo)

Once the Codespace loads, run:
```bash
./scripts/demo.sh
```

This runs a complete demo showing:
- ✅ SQL validation (no database needed)
- ✅ Migration status tracking
- ✅ Applying migrations
- ✅ Schema drift detection
- ✅ Migration rollback
- ✅ Schema export

### 🎮 Interactive: Manual Commands
Follow the step-by-step guide: **[QUICKSTART.md](QUICKSTART.md)**

Try each command yourself and see real results!

---

## Quick Start (5 Minutes)

> ✅ **Docker images are now working!** JVM issues have been resolved. See [DOCKER_ISSUES.md](DOCKER_ISSUES.md) for details on the fix.

### Step 1: Clone the Demo Repository

```bash
git clone https://github.com/dblift/dblift-demo.git
cd dblift-demo
```

### Step 2: Start the Database & Warm DBLift CLI

```bash
docker compose up -d postgres dblift-cli
```

This starts the database container (`dblift-demo-postgres`) and keeps a DBLift CLI container running so commands execute immediately.

### Step 3: Run Migrations with Docker

```bash
docker compose exec dblift-cli dblift migrate --config config/dblift-postgresql-docker.yaml
```

**💡 Tip:** Create an alias for convenience:
```bash
alias dblift='docker compose exec dblift-cli dblift'

# Then simply use (after Step 2):
dblift migrate --config config/dblift-postgresql-docker.yaml
```

**📝 Note:** Use `config/dblift-postgresql-docker.yaml` when running from Docker (uses container networking).
Use `config/dblift-postgresql.yaml` when running DBLift installed locally.

### Step 4: View Migration Status

```bash
docker compose exec dblift-cli dblift info --config config/dblift-postgresql-docker.yaml

# Or with the alias established above:
dblift info --config config/dblift-postgresql-docker.yaml
```

Done! 🎉

### Alternative: Install DBLift Locally

If you prefer not to use Docker:

**Option A: Download Binary**
```bash
# Linux
curl -L -o dblift-linux-x64.tar.gz \
  https://github.com/dblift/dblift/releases/latest/download/dblift-linux-x64.tar.gz
tar xzf dblift-linux-x64.tar.gz
export PATH="$PATH:$(pwd)/dblift-linux-x64"

# macOS
curl -L -o dblift-macos-arm64.tar.gz \
  https://github.com/dblift/dblift/releases/latest/download/dblift-macos-arm64.tar.gz
tar xzf dblift-macos-arm64.tar.gz
export PATH="$PATH:$(pwd)/dblift-macos-arm64"
```

**Option B: Install from Source**
```bash
git clone https://github.com/dblift/dblift.git
cd dblift
pip install -e .
```

See [INSTALL.md](INSTALL.md) for detailed instructions.

## What's Included

- 📦 **Migration Examples** - Versioned, repeatable, and undo migrations
- ✅ **Validation Rules** - Custom SQL validation with business rules
- 🔄 **CI/CD Examples** - GitHub Actions workflows
- 🗄️ **Multi-Database Support** - PostgreSQL, SQL Server, MySQL
- 📚 **9 Demo Scenarios** - Step-by-step walkthroughs
- ⚙️ **Configuration Examples** - Production-ready configs

## Demo Scenarios

| # | Scenario | Description | Time |
|---|----------|-------------|------|
| 01 | [Basic Migration](scenarios/01-basic-migration/) | Getting started | 10 min |
| 02 | [Validation Rules](scenarios/02-validation-rules/) | SQL quality checks | 15 min |
| 03 | [Undo Playbook](scenarios/03-undo-playbook/) | Latest, target, and specific undo flows | 15 min |
| 04 | [Checksum Repair](scenarios/04-checksum-repair/) | Detect and repair history corruption | 15 min |
| 05 | [Drift Detection](scenarios/05-drift-detection/) | Schema monitoring | 15 min |
| 06 | [CI/CD Integration](scenarios/06-ci-cd-integration/) | Automation | 20 min |
| 07 | [Tag-Based Deployment](scenarios/07-tag-based-deployment/) | Selective rollout | 15 min |
| 08 | [Brownfield Migration](scenarios/08-brownfield-migration/) | Existing databases | 20 min |
| 09 | [Schema Export](scenarios/10-export-schema/) | SQL export and JSON schema model | 10 min |

## Repository Structure

```
dblift-demo/
├── migrations/           # SQL migration examples
│   ├── core/            # Core schema
│   ├── features/        # Feature-specific
│   ├── performance/     # Optimizations
│   └── security/        # Security enhancements
├── config/              # Configuration files
├── scenarios/           # Demo walkthroughs
├── .github/workflows/   # CI/CD examples
├── sample-data/         # Sample data scripts
└── docs/               # Documentation
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

- **Releases**: https://github.com/cmodiano/dblift/releases
- **Docker**: `ghcr.io/cmodiano/dblift:latest`
- **Docker (Validation)**: `ghcr.io/cmodiano/dblift-validation:latest`
- **Documentation**: https://github.com/cmodiano/dblift
- **Issues**: https://github.com/cmodiano/dblift/issues

## Support

- Website: https://dblift.com
- Documentation: https://dblift.com/docs
- Issues: https://github.com/cmodiano/dblift/issues
- Email: contact@dblift.com

## Contributing

This is a demo repository showing how to use DBLift.

To contribute to DBLift itself or report issues:
- Main repository: https://github.com/cmodiano/dblift
- Issues: https://github.com/cmodiano/dblift/issues

## License

Demo content: MIT License
DBLift: See main repository for license

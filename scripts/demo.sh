#!/bin/bash
# DBLift Interactive Demo Script
# Run this to see all DBLift features in action

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Helper function to run dblift commands
dblift() {
  docker run --rm \
    -v "$(pwd):/workspace" \
    --network dblift-demo_default \
    -e DBLIFT_DB_URL=jdbc:postgresql://postgres:5432/dblift_demo \
    -e DBLIFT_DB_USER=dblift_user \
    -e DBLIFT_DB_PASSWORD=dblift_pass \
    -e DBLIFT_DB_SCHEMA=public \
    ghcr.io/cmodiano/dblift:latest "$@" \
    --config /workspace/config/dblift-postgresql.yaml
}

# Helper for validation-only image
validate() {
  docker run --rm \
    -v "$(pwd):/workspace" \
    ghcr.io/cmodiano/dblift-validation:latest "$@"
}

echo -e "${BLUE}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║        DBLift Interactive Demo                       ║${NC}"
echo -e "${BLUE}║  Hands-on Database Migration Management              ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════╝${NC}"
echo ""

# Step 1: Check if PostgreSQL is running
echo -e "${GREEN}[Step 1/9]${NC} Checking PostgreSQL..."
if ! docker ps | grep -q dblift-demo-postgres; then
  echo "Starting PostgreSQL..."
  docker-compose up -d
  echo "Waiting for PostgreSQL to be ready..."
  sleep 5
fi
echo "✓ PostgreSQL is running"
echo ""

# Step 2: Validate SQL files
echo -e "${GREEN}[Step 2/9]${NC} Validating SQL files (no database needed)..."
validate validate-sql /workspace/migrations/ \
  --dialect postgresql \
  --rules-file /workspace/config/.dblift_rules.yaml \
  --format compact
echo ""

# Step 3: Check initial migration status
echo -e "${GREEN}[Step 3/9]${NC} Checking initial migration status..."
dblift info
echo ""

# Step 4: Apply all migrations
echo -e "${GREEN}[Step 4/9]${NC} Applying migrations..."
dblift migrate --log-dir /workspace/logs
echo ""

# Step 5: Check status after migration
echo -e "${GREEN}[Step 5/9]${NC} Verifying migrations applied..."
dblift info
echo ""

# Step 6: Simulate drift
echo -e "${GREEN}[Step 6/9]${NC} Simulating schema drift..."
echo -e "${YELLOW}Adding a manual column to 'users' table...${NC}"
docker exec dblift-demo-postgres-1 psql -U dblift_user -d dblift_demo -c \
  "ALTER TABLE users ADD COLUMN phone VARCHAR(20); \
   COMMENT ON COLUMN users.phone IS 'This column was added manually (not via migration)';" \
  2>&1 | grep -v "^$"
echo ""

# Step 7: Detect drift
echo -e "${GREEN}[Step 7/9]${NC} Detecting schema drift..."
set +e
dblift diff
DRIFT_EXIT=$?
set -e
echo ""

# Step 8: Rollback one migration
echo -e "${GREEN}[Step 8/9]${NC} Rolling back last migration..."
dblift undo
echo ""

# Step 9: Export schema
echo -e "${GREEN}[Step 9/9]${NC} Exporting current schema..."
dblift export --output /workspace/schema_export.sql
echo "✓ Schema exported to: schema_export.sql"
echo ""

# Summary
echo -e "${BLUE}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║              Demo Complete! 🎉                        ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════╝${NC}"
echo ""
echo "What you just saw:"
echo "  ✓ SQL validation without database"
echo "  ✓ Migration status tracking"
echo "  ✓ Applying migrations with full logging"
echo "  ✓ Schema drift detection"
echo "  ✓ Migration rollback"
echo "  ✓ Schema export"
echo ""
echo "Next steps:"
echo "  • Check logs/: HTML reports with detailed analytics"
echo "  • View schema_export.sql: Full schema DDL"
echo "  • Try scenarios/: Explore specific use cases"
echo "  • Run individual commands from QUICKSTART.md"
echo ""
echo "Cleanup: docker-compose down -v"


#!/bin/bash
# DBLift Demo - Cleanup Script
# Removes demo data and resets environment

set -e

echo "🧹 Cleaning up demo environment..."

# Stop and remove containers
echo "Stopping Docker containers..."
docker-compose down -v

# Remove logs
echo "Removing log files..."
rm -rf logs/
rm -f *.log
rm -f *.html
rm -f *.sarif

# Remove downloaded dblift binaries
echo "Removing downloaded binaries..."
rm -rf dblift-*/ dblift dblift.exe
rm -f *.tar.gz *.zip

# Remove temporary files
echo "Removing temporary files..."
rm -rf tmp/ temp/

echo "✅ Cleanup complete!"
echo ""
echo "To start fresh:"
echo "1. docker-compose up -d postgres"
echo "2. dblift migrate --config config/dblift-postgresql.yaml"


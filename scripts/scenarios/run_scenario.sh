#!/usr/bin/env bash

# DBLift Demo Scenario Runner
# Executes scenario walkthroughs inside CI to produce rich, visual output.

set -euo pipefail

SCENARIO_ID="${1:-}"
SCENARIO_NAME="${2:-}"

if [[ -z "${SCENARIO_ID}" ]]; then
  echo "Usage: $0 <scenario-id> [scenario-name]" >&2
  exit 1
fi

# Discover repository root (workspace) even if script executed via relative path
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE="${GITHUB_WORKSPACE:-$(cd "${SCRIPT_DIR}/../.." && pwd)}"

LOG_ROOT="${WORKSPACE}/logs/scenario-${SCENARIO_ID}"
mkdir -p "${LOG_ROOT}"

SUMMARY_FILE="${GITHUB_STEP_SUMMARY:-${LOG_ROOT}/summary.md}"
LOG_FILE="${LOG_ROOT}/run.log"
touch "${LOG_FILE}"

DB_HOST="${DB_HOST:-127.0.0.1}"
DB_PORT="${DB_PORT:-5432}"
DB_NAME="${DB_NAME:-dblift_demo}"
DB_USER="${DB_USER:-dblift_user}"
DB_PASSWORD="${DB_PASSWORD:-dblift_pass}"
DB_SCHEMA="${DB_SCHEMA:-public}"
DB_URL_DEFAULT="jdbc:postgresql://${DB_HOST}:${DB_PORT}/${DB_NAME}"

SCENARIO_TITLE="Scenario ${SCENARIO_ID}"
if [[ -n "${SCENARIO_NAME}" ]]; then
  SCENARIO_TITLE+=" - ${SCENARIO_NAME}"
fi

declare -A HISTORY_SNAPSHOTS=()
LAST_LOG_PATH=""

# ---------------------------------------------------------------------------
# Helper utilities
# ---------------------------------------------------------------------------

append_summary() {
  printf '%s\n' "$1" >> "${SUMMARY_FILE}"
}

log_group_start() {
  printf '::group::%s\n' "$1"
}

log_group_end() {
  echo "::endgroup::"
}

# Sanitize a string to use as filename suffix
slugify() {
  local input="$1"
  echo "${input}" | tr '[:upper:]' '[:lower:]' | tr -cs '[:alnum:]_' '-' | sed 's/^-*//;s/-*$//'
}

write_log_output() {
  local title="$1"
  local content="$2"
  local status="$3"
  local slug
  slug="$(slugify "${title}")"
  [[ -z "${slug}" ]] && slug="step"
  local outfile="${LOG_ROOT}/${slug}.log"
  printf '%s\n' "${content}" > "${outfile}"
  printf '%s\n' "${content}" >> "${LOG_FILE}"
  printf 'status=%s\n' "${status}" >> "${outfile}.meta"
  echo "${outfile}"
}

show_log_excerpt() {
  local heading="$1"
  local log_path="$2"
  local max_lines="${3:-120}"

  [[ -f "${log_path}" ]] || return 0

  append_summary "### ${heading}"
  append_summary ""
  append_summary '```'
  local line_count=0
  while IFS= read -r line && (( line_count < max_lines )); do
    append_summary "${line}"
    line_count=$((line_count + 1))
  done < "${log_path}"
  append_summary '```'
  append_summary ""
}

run_command() {
  local title="$1"
  shift
  log_group_start "${title}"
  local output status
  set +e
  output="$("$@" 2>&1)"
  status=$?
  set -e
  log_group_end
  local log_path
  log_path="$(write_log_output "${title}" "${output}" "${status}")"
  LAST_LOG_PATH="${log_path}"
  return "${status}"
}

docker_base_args() {
  local overrides=("$@")
  printf '%s\n' \
    "--rm" \
    "-v" "${WORKSPACE}:/workspace" \
    "--network" "host" \
    "-w" "/workspace" \
    "-e" "DBLIFT_DB_URL=${DB_URL_DEFAULT}" \
    "-e" "DBLIFT_DB_USER=${DB_USER}" \
    "-e" "DBLIFT_DB_PASSWORD=${DB_PASSWORD}" \
    "-e" "DBLIFT_DB_SCHEMA=${DB_SCHEMA}"
  printf '%s\n' "${overrides[@]}"
}

run_dblift() {
  local title="$1"
  shift
  local output status
  log_group_start "${title}"
  set +e
  output="$(docker run $(docker_base_args) ghcr.io/cmodiano/dblift:latest "$@" 2>&1)"
  status=$?
  set -e
  log_group_end
  local log_path
  log_path="$(write_log_output "${title}" "${output}" "${status}")"
  LAST_LOG_PATH="${log_path}"
  return "${status}"
}

run_dblift_custom_db() {
  local title="$1"
  local url="$2"
  shift 2
  local output status
  log_group_start "${title}"
  set +e
  output="$(docker run $(docker_base_args "-e" "DBLIFT_DB_URL=${url}") ghcr.io/cmodiano/dblift:latest "$@" 2>&1)"
  status=$?
  set -e
  log_group_end
  local log_path
  log_path="$(write_log_output "${title}" "${output}" "${status}")"
  LAST_LOG_PATH="${log_path}"
  return "${status}"
}

wait_for_db() {
  local url="${1:-${DB_URL_DEFAULT}}"
  local host port db
  host="$(echo "${url}" | sed -E 's#jdbc:postgresql://([^:/]+):([0-9]+)/([^?]+).*#\1#')"
  port="$(echo "${url}" | sed -E 's#jdbc:postgresql://([^:/]+):([0-9]+)/([^?]+).*#\2#')"
  db="$(echo "${url}" | sed -E 's#jdbc:postgresql://([^:/]+):([0-9]+)/([^?]+).*#\3#')"
  local attempt=0
  local max_attempts=15

  while (( attempt < max_attempts )); do
    if docker run --rm --network host -e PGPASSWORD="${DB_PASSWORD}" postgres:15-alpine \
      pg_isready -h "${host}" -p "${port}" -U "${DB_USER}" -d "${db}" >/dev/null 2>&1; then
      return 0
    fi
    attempt=$((attempt + 1))
    sleep 2
  done

  echo "Database ${url} did not become ready in time" >&2
  return 1
}

psql_exec() {
  local title="$1"
  local sql="$2"
  local url="${3:-${DB_URL_DEFAULT}}"
  local host port db
  host="$(echo "${url}" | sed -E 's#jdbc:postgresql://([^:/]+):([0-9]+)/([^?]+).*#\1#')"
  port="$(echo "${url}" | sed -E 's#jdbc:postgresql://([^:/]+):([0-9]+)/([^?]+).*#\2#')"
  db="$(echo "${url}" | sed -E 's#jdbc:postgresql://([^:/]+):([0-9]+)/([^?]+).*#\3#')"
  run_command "${title}" docker run --rm --network host \
    -e PGPASSWORD="${DB_PASSWORD}" \
    postgres:15-alpine \
    psql -h "${host}" -p "${port}" -U "${DB_USER}" -d "${db}" -v ON_ERROR_STOP=1 -c "${sql}"
}

psql_file() {
  local title="$1"
  local file_path="$2"
  local url="${3:-${DB_URL_DEFAULT}}"
  local host port db
  host="$(echo "${url}" | sed -E 's#jdbc:postgresql://([^:/]+):([0-9]+)/([^?]+).*#\1#')"
  port="$(echo "${url}" | sed -E 's#jdbc:postgresql://([^:/]+):([0-9]+)/([^?]+).*#\2#')"
  db="$(echo "${url}" | sed -E 's#jdbc:postgresql://([^:/]+):([0-9]+)/([^?]+).*#\3#')"
  run_command "${title}" docker run --rm --network host \
    -e PGPASSWORD="${DB_PASSWORD}" \
    -v "${WORKSPACE}:/workspace" \
    postgres:15-alpine \
    psql -h "${host}" -p "${port}" -U "${DB_USER}" -d "${db}" -v ON_ERROR_STOP=1 -f "/workspace/${file_path}"
}

psql_query() {
  local title="$1"
  local sql="$2"
  local url="${3:-${DB_URL_DEFAULT}}"
  local host port db
  host="$(echo "${url}" | sed -E 's#jdbc:postgresql://([^:/]+):([0-9]+)/([^?]+).*#\1#')"
  port="$(echo "${url}" | sed -E 's#jdbc:postgresql://([^:/]+):([0-9]+)/([^?]+).*#\2#')"
  db="$(echo "${url}" | sed -E 's#jdbc:postgresql://([^:/]+):([0-9]+)/([^?]+).*#\3#')"

  log_group_start "${title}"
  set +e
  local output
  output="$(docker run --rm --network host \
    -e PGPASSWORD="${DB_PASSWORD}" \
    postgres:15-alpine \
    psql -h "${host}" -p "${port}" -U "${DB_USER}" -d "${db}" \
      -v ON_ERROR_STOP=1 -At -F '|' -c "${sql}" 2>&1)"
  local status=$?
  set -e
  log_group_end
  write_log_output "${title}" "${output}" "${status}" >/dev/null
  printf '%s' "${output}"
  return "${status}"
}

capture_migration_state() {
  local heading="$1"
  local snapshot_id="${2:-}"
  local url="${3:-${DB_URL_DEFAULT}}"

  append_summary ""
  append_summary "### ${heading}"
  append_summary ""

  local sql="SELECT installed_rank, COALESCE(version, '-') AS version, COALESCE(NULLIF(description, ''), script) AS description, CASE WHEN success THEN 'success' ELSE 'failed' END AS status, installed_by, to_char(installed_on, 'YYYY-MM-DD HH24:MI:SS') AS installed_on FROM dblift_schema_history ORDER BY installed_rank;"
  local raw_output
  if ! raw_output="$(psql_query "Inspect schema history (${heading})" "${sql}" "${url}")"; then
    if echo "${raw_output}" | grep -qi "does not exist"; then
      append_summary "_Schema history table not created yet._"
    else
      append_summary "_Unable to query schema history._"
      append_summary ""
      append_summary '```'
      append_summary "${raw_output}"
      append_summary '```'
    fi
    return 0
  fi

  if [[ -z "${raw_output}" ]]; then
    append_summary "_No migrations recorded yet._"
  else
    append_summary "| Rank | Version | Description | Status | Applied By | Applied At |"
    append_summary "|------|---------|-------------|--------|------------|------------|"
    while IFS='|' read -r rank version description status installed_by installed_on; do
      [[ -z "${rank}" ]] && continue
      local status_icon="❌"
      [[ "${status}" == "success" ]] && status_icon="✅"
      append_summary "| ${rank} | ${version} | ${description} | ${status_icon} | ${installed_by} | ${installed_on} |"
    done <<<"${raw_output}"
  fi

  if [[ -n "${snapshot_id}" ]]; then
    local snapshot_file="${LOG_ROOT}/schema-history-${snapshot_id}.txt"
    printf '%s\n' "${raw_output}" > "${snapshot_file}"
    HISTORY_SNAPSHOTS["${snapshot_id}"]="${snapshot_file}"
  fi
}

compare_history_snapshots() {
  local from_id="$1"
  local to_id="$2"
  local from_file="${HISTORY_SNAPSHOTS["${from_id}"]:-}"
  local to_file="${HISTORY_SNAPSHOTS["${to_id}"]:-}"

  [[ -n "${to_file}" && -f "${to_file}" ]] || return 0

  local new_entries
  if [[ -n "${from_file}" && -f "${from_file}" ]]; then
    new_entries="$(grep -F -x -v -f "${from_file}" "${to_file}" || true)"
  else
    new_entries="$(cat "${to_file}")"
  fi

  [[ -z "${new_entries}" ]] && return 0

  append_summary ""
  append_summary "#### ✅ Newly applied migrations"
  append_summary ""
  append_summary "| Version | Description | Applied By | Applied At |"
  append_summary "|---------|-------------|------------|------------|"
  while IFS='|' read -r rank version description status installed_by installed_on; do
    [[ -z "${rank}" ]] && continue
    [[ "${status}" != "success" ]] && continue
    append_summary "| ${version} | ${description} | ${installed_by} | ${installed_on} |"
  done <<<"${new_entries}"
}

on_error() {
  local exit_code="${1:-1}"
  local line_no="${2:-}"
  append_summary ""
  append_summary "❌ Scenario failed (exit code ${exit_code}) at line ${line_no}"
  exit "${exit_code}"
}

trap 'on_error $? $LINENO' ERR

# ---------------------------------------------------------------------------
# Scenario implementations
# ---------------------------------------------------------------------------

append_summary "# ${SCENARIO_TITLE}"
append_summary ""
append_summary "- Workspace: \`${WORKSPACE}\`"
append_summary "- Logs: \`${LOG_ROOT}\`"
append_summary ""

case "${SCENARIO_ID}" in
  "01")
    append_summary "## Overview"
    append_summary "- **Goal**: Apply the baseline schema to a fresh database."
    append_summary "- **Focus**: Showcase `dblift migrate` and how migration progress appears in the history table."
    append_summary "- **Key Questions**: What migrations are pending? Which ones got applied in this run?"
    append_summary ""
    append_summary "## Timeline"
    append_summary "- 🔍 Inspect the existing schema history (should be empty for a fresh DB)."
    append_summary "- ▶️ Execute `dblift migrate` using `config/dblift-postgresql.yaml`."
    append_summary "- ✅ Confirm the new entries recorded in `dblift_schema_history`."
    append_summary ""

    wait_for_db
    capture_migration_state "Schema history before running migrations" "before-migrate"
    run_dblift "Check database status (before)" info --config config/dblift-postgresql.yaml
    BEFORE_INFO_LOG="${LAST_LOG_PATH}"
    show_log_excerpt "📋 Database status (before migrations)" "${BEFORE_INFO_LOG}" 80
    run_dblift "Run migrations" migrate --config config/dblift-postgresql.yaml --log-format text --log-dir logs
    run_dblift "Check database status (after)" info --config config/dblift-postgresql.yaml
    AFTER_INFO_LOG="${LAST_LOG_PATH}"
    capture_migration_state "Schema history after running migrations" "after-migrate"
    compare_history_snapshots "before-migrate" "after-migrate"
    show_log_excerpt "📋 Database status (after migrations)" "${AFTER_INFO_LOG}" 80
    append_summary ""
    append_summary "## Outcome"
    append_summary "- ✅ Baseline migrations applied with `dblift migrate`."
    append_summary "- 📊 Schema history table updated; new rows listed above."
    append_summary "- 📁 Detailed command logs uploaded as workflow artifacts."
    ;;

  "02")
    append_summary "## Overview"
    append_summary "- **Goal**: Experience DBLift's validation engine catching real violations."
    append_summary "- **Focus**: Run validations on good vs. intentionally bad SQL and compare summaries."
    append_summary "- **What You’ll See**: Rich console output with counts by severity and rule category."
    append_summary ""
    append_summary "## Timeline"
    append_summary "- ✅ Validate the repository’s existing migrations (expected to pass)."
    append_summary "- ❌ Introduce an intentional “bad” migration directory and validate it (expected to fail)."
    append_summary "- ✅ Fix the issues and re-run validation to confirm they disappear."
    append_summary ""

    run_dblift "Validate existing migrations" validate-sql migrations/ \
      --dialect postgresql \
      --rules-file config/.dblift_rules.yaml \
      --format console

    BAD_SRC_DIR="migrations/examples/bad-demo"
    mkdir -p "${BAD_SRC_DIR}"
    BAD_FILE="${BAD_SRC_DIR}/V9_9_9__bad_example.sql"
    cat > "${BAD_FILE}" <<'SQL'
-- Intentional violations for Scenario 02
CREATE TABLE BadTable (
    name VARCHAR(100)
);

CREATE TABLE AnotherBadTable (
    id INTEGER PRIMARY KEY,
    value TEXT
);

CREATE TABLE orders_bad (
    id INTEGER PRIMARY KEY,
    customer_id INTEGER REFERENCES customers(id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by VARCHAR(50) DEFAULT 'system'
);

INSERT INTO BadTable SELECT * FROM users;
DELETE FROM BadTable;
SQL

    run_dblift "Validate bad migration (expected failures)" validate-sql "${BAD_SRC_DIR}/" \
      --dialect postgresql \
      --rules-file config/.dblift_rules.yaml \
      --format console || true
    BAD_LOG="${LAST_LOG_PATH}"
    if [[ -f "${BAD_LOG}" ]]; then
      append_summary "### 🔍 Failure Output Snapshot"
      append_summary ""
      append_summary '```'
      while IFS= read -r line; do
        append_summary "${line}"
      done < <(head -n 120 "${BAD_LOG}")
      append_summary '```'
      append_summary ""
    fi

    GOOD_FILE="${BAD_SRC_DIR}/V9_9_9__good_example.sql"
    cat > "${GOOD_FILE}" <<'SQL'
CREATE TABLE GoodTable (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by VARCHAR(50) DEFAULT 'system' NOT NULL
);
SQL

    run_dblift "Validate fixed migration" validate-sql "${GOOD_FILE}" \
      --dialect postgresql \
      --rules-file config/.dblift_rules.yaml \
      --format console

    append_summary "- ✅ Baseline migrations pass validation."
    append_summary "- ❌ Intentional violations captured by validation rules."
    append_summary "- ✅ After fixes, validation succeeds again."
    ;;

  "03")
    append_summary "## Step Summary"
    append_summary "- Showcasing rollback, corruption detection, and repair."
    wait_for_db
    run_dblift "Apply migrations through current version" migrate --config config/dblift-postgresql.yaml
    run_dblift "Confirm schema status" info --config config/dblift-postgresql.yaml

    run_dblift "Rollback to version 1.0.2" undo \
      --config config/dblift-postgresql.yaml \
      --target-version 1.0.2
    run_dblift "Verify rollback state" info --config config/dblift-postgresql.yaml

    run_dblift "Reapply migrations" migrate --config config/dblift-postgresql.yaml

    psql_exec "Simulate checksum corruption" \
      "UPDATE dblift_schema_history SET checksum = 'corrupted' WHERE version = '1.0.3';"

    if ! run_dblift "Detect corruption via validation" validate --config config/dblift-postgresql.yaml; then
      append_summary "- ⚠️ Detected checksum mismatch after manual corruption."
    fi

    run_dblift "Repair schema history" repair --config config/dblift-postgresql.yaml
    run_dblift "Re-validate after repair" validate --config config/dblift-postgresql.yaml
    append_summary "- ✅ Undo migration executed and verified."
    append_summary "- ✅ Corruption detected and automatically repaired."
    ;;

  "04")
    append_summary "## Step Summary"
    append_summary "- Demonstrating multi-environment deployment (dev/staging/prod)."

    wait_for_db "${DB_URL_DEFAULT}"

    STAGING_CONTAINER="dblift-demo-staging-${GITHUB_RUN_ID:-$$}"
    PROD_CONTAINER="dblift-demo-prod-${GITHUB_RUN_ID:-$$}"

    docker rm -f "${STAGING_CONTAINER}" "${PROD_CONTAINER}" >/dev/null 2>&1 || true

    run_command "Start staging database (port 5433)" docker run -d \
      --name "${STAGING_CONTAINER}" \
      -e POSTGRES_DB=dblift_staging \
      -e POSTGRES_USER="${DB_USER}" \
      -e POSTGRES_PASSWORD="${DB_PASSWORD}" \
      -p 5433:5432 \
      postgres:15-alpine

    run_command "Start production database (port 5434)" docker run -d \
      --name "${PROD_CONTAINER}" \
      -e POSTGRES_DB=dblift_prod \
      -e POSTGRES_USER="${DB_USER}" \
      -e POSTGRES_PASSWORD="${DB_PASSWORD}" \
      -p 5434:5432 \
      postgres:15-alpine

    trap 'docker rm -f "${STAGING_CONTAINER}" "${PROD_CONTAINER}" >/dev/null 2>&1 || true; on_error $? $LINENO' ERR

    wait_for_db "jdbc:postgresql://127.0.0.1:5433/dblift_staging"
    wait_for_db "jdbc:postgresql://127.0.0.1:5434/dblift_prod"

    CONFIG_DIR="${LOG_ROOT}/configs"
    mkdir -p "${CONFIG_DIR}"

    DEV_CONFIG="${CONFIG_DIR}/dblift-dev.yaml"
    cat > "${DEV_CONFIG}" <<EOF
database:
  url: "jdbc:postgresql://127.0.0.1:5432/dblift_demo"
  schema: "${DB_SCHEMA}"
  username: "${DB_USER}"
  password: "${DB_PASSWORD}"

migrations:
  directory: "./migrations/core"
  directories:
    - "./migrations/features"
  recursive: true

logging:
  level: DEBUG
  log_format: "text"
  log_dir: "./logs/dev"
EOF

    STAGING_CONFIG="${CONFIG_DIR}/dblift-staging.yaml"
    cat > "${STAGING_CONFIG}" <<EOF
database:
  url: "jdbc:postgresql://127.0.0.1:5433/dblift_staging"
  schema: "${DB_SCHEMA}"
  username: "${DB_USER}"
  password: "${DB_PASSWORD}"

migrations:
  directory: "./migrations/core"
  directories:
    - "./migrations/features"
    - "./migrations/performance"
  recursive: true

validation:
  enabled: true
  fail_on_violations: true
  rules_file: "config/.dblift_rules.yaml"

logging:
  level: INFO
  log_format: "text,json"
  log_dir: "./logs/staging"
EOF

    PROD_CONFIG="${CONFIG_DIR}/dblift-prod.yaml"
    cat > "${PROD_CONFIG}" <<EOF
database:
  url: "jdbc:postgresql://127.0.0.1:5434/dblift_prod"
  schema: "${DB_SCHEMA}"
  username: "${DB_USER}"
  password: "${DB_PASSWORD}"

migrations:
  directory: "./migrations/core"
  directories:
    - "./migrations/features"
    - "./migrations/performance"
    - "./migrations/security"
  recursive: true

validation:
  enabled: true
  fail_on_violations: true
  severity_threshold: "error"
  rules_file: "config/.dblift_rules.yaml"

logging:
  level: WARN
  log_format: "json,html"
  log_dir: "./logs/prod"
EOF

    run_dblift "Deploy to development" migrate --config "${DEV_CONFIG}"
    run_dblift "Dev status" info --config "${DEV_CONFIG}"

    run_dblift "Validate staging" validate --config "${STAGING_CONFIG}"
    run_dblift "Deploy to staging" migrate --config "${STAGING_CONFIG}"
    run_dblift "Staging drift check" diff --config "${STAGING_CONFIG}"

    run_dblift "Production dry-run" migrate --config "${PROD_CONFIG}" --dry-run
    run_dblift "Production deploy" migrate --config "${PROD_CONFIG}"
    run_dblift "Production status" info --config "${PROD_CONFIG}"

    append_summary "- ✅ Dev, staging, and prod configs generated dynamically."
    append_summary "- ✅ Validated staging before deployment."
    append_summary "- ✅ Production dry-run completed prior to live deploy."

    docker rm -f "${STAGING_CONTAINER}" "${PROD_CONTAINER}" >/dev/null 2>&1 || true
    ;;

  "05")
    append_summary "## Step Summary"
    append_summary "- Demonstrating schema drift detection workflow."
    wait_for_db
    run_dblift "Apply migrations" migrate --config config/dblift-postgresql.yaml
    run_dblift "Initial drift check" diff --config config/dblift-postgresql.yaml
    psql_file "Simulate drift changes" scripts/simulate-drift.sql

    if ! run_dblift "Detect drift after manual changes" diff --config config/dblift-postgresql.yaml; then
      append_summary "- ⚠️ Drift detected after manual schema changes."
    fi

    run_dblift "Generate HTML drift report" diff \
      --config config/dblift-postgresql.yaml \
      --log-format html \
      --log-dir "${LOG_ROOT}/reports"

    run_dblift "Generate JSON drift report" diff \
      --config config/dblift-postgresql.yaml \
      --format json \
      --output "${LOG_ROOT}/drift-report.json"

    append_summary "- ✅ Clean drift check passes before manual changes."
    append_summary "- ✅ Drift detected and reports produced for review."
    ;;

  "06")
    append_summary "## Step Summary"
    append_summary "- Highlighting CI/CD integration pieces."
    append_summary ""

    run_command "List available workflows" ls -1 .github/workflows
    run_command "Show SQL validation workflow" cat .github/workflows/validate-sql.yml

    run_dblift "Generate SARIF validation report" validate-sql migrations/ \
      --dialect postgresql \
      --rules-file config/.dblift_rules.yaml \
      --format sarif \
      --output "${LOG_ROOT}/validation-results.sarif"

    run_command "Preview SARIF report headers" head -n 40 "${LOG_ROOT}/validation-results.sarif"

    append_summary "- ✅ Workflows enumerated for quick reference."
    append_summary "- ✅ SARIF validation report generated for code scanning integration."
    ;;

  "07")
    append_summary "## Step Summary"
    append_summary "- Performing selective deployments using tags."
    wait_for_db
    run_dblift "Apply core schema only" migrate \
      --config config/dblift-postgresql.yaml \
      --exclude-tags user-mgmt,notifications,analytics,security

    run_dblift "Deploy user management features" migrate \
      --config config/dblift-postgresql.yaml \
      --tags user-mgmt

    run_dblift "Deploy notifications" migrate \
      --config config/dblift-postgresql.yaml \
      --tags notifications

    run_dblift "Check security tag status" info \
      --config config/dblift-postgresql.yaml \
      --tags security

    run_dblift "Deploy everything except analytics" migrate \
      --config config/dblift-postgresql.yaml \
      --exclude-tags analytics

    append_summary "- ✅ Core migrations deployed without optional feature tags."
    append_summary "- ✅ Targeted feature deployments executed via tags."
    append_summary "- ✅ Tag-filtered status inspection completed."
    ;;

  "08")
    append_summary "## Step Summary"
    append_summary "- Simulating brownfield adoption with baseline and new changes."
    wait_for_db

    psql_file "Reset demo schema" migrations/core/V1_0_0__Initial_schema.sql
    psql_file "Load additional baseline objects" migrations/core/V1_0_1__Add_customers.sql
    psql_file "Load more baseline objects" migrations/core/V1_0_2__Add_products.sql

    BROWNFIELD_DIR="${LOG_ROOT}/brownfield"
    mkdir -p "${BROWNFIELD_DIR}/migrations"
    cp migrations/core/V1_0_0__Initial_schema.sql "${BROWNFIELD_DIR}/migrations/V1_0_0__Baseline_existing_schema.sql"

    cat > "${BROWNFIELD_DIR}/dblift-brownfield.yaml" <<EOF
database:
  url: "${DB_URL_DEFAULT}"
  schema: "${DB_SCHEMA}"
  username: "${DB_USER}"
  password: "${DB_PASSWORD}"

migrations:
  directory: "./logs/scenario-${SCENARIO_ID}/brownfield/migrations"
  recursive: true

logging:
  level: INFO
  log_format: "text"
  log_dir: "./logs/scenario-${SCENARIO_ID}/brownfield/logs"
EOF

    run_dblift "Baseline existing database" baseline \
      --config "${BROWNFIELD_DIR}/dblift-brownfield.yaml" \
      --baseline-version 1.0.0 \
      --baseline-description "Initial baseline of existing production database"

    NEW_MIG="${BROWNFIELD_DIR}/migrations/V1_0_1__Add_api_keys_table.sql"
    cat > "${NEW_MIG}" <<'SQL'
CREATE TABLE IF NOT EXISTS api_keys (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id),
    key_hash VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by VARCHAR(50) DEFAULT 'system' NOT NULL
);
SQL

    run_dblift "Apply post-baseline migration" migrate --config "${BROWNFIELD_DIR}/dblift-brownfield.yaml"
    run_dblift "Inspect status after baseline + new migration" info --config "${BROWNFIELD_DIR}/dblift-brownfield.yaml"

    append_summary "- ✅ Database baselined without executing legacy changes."
    append_summary "- ✅ New migrations applied on top of baseline safely."
    ;;

  "09")
    append_summary "## Step Summary"
    append_summary "- Managing multi-module migrations with directory orchestration."
    wait_for_db

    MODULE_ROOT="${LOG_ROOT}/modules"
    mkdir -p "${MODULE_ROOT}/inventory/migrations" "${MODULE_ROOT}/crm/migrations" "${MODULE_ROOT}/analytics/migrations"

    cat > "${MODULE_ROOT}/inventory/migrations/V3_0_0__Create_inventory_schema[inventory].sql" <<'SQL'
CREATE TABLE IF NOT EXISTS inventory_items (
    id SERIAL PRIMARY KEY,
    product_id INTEGER NOT NULL REFERENCES products(id),
    warehouse_location VARCHAR(100),
    quantity INTEGER NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by VARCHAR(50) DEFAULT 'system' NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_inventory_product ON inventory_items(product_id);
SQL

    cat > "${MODULE_ROOT}/crm/migrations/V3_1_0__Create_crm_schema[crm].sql" <<'SQL'
CREATE TABLE IF NOT EXISTS crm_contacts (
    id SERIAL PRIMARY KEY,
    customer_id INTEGER REFERENCES customers(id),
    contact_type VARCHAR(50),
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by VARCHAR(50) DEFAULT 'system' NOT NULL
);
SQL

    cat > "${MODULE_ROOT}/analytics/migrations/V3_2_0__Create_analytics_views[analytics].sql" <<'SQL'
CREATE VIEW IF NOT EXISTS analytics_orders_summary AS
SELECT c.name AS customer_name,
       COUNT(o.id) AS total_orders,
       SUM(o.total_amount) AS total_amount
FROM customers c
LEFT JOIN orders o ON c.id = o.customer_id
GROUP BY c.name;
SQL

    MULTI_CONFIG="${LOG_ROOT}/dblift-multi-module.yaml"
    cat > "${MULTI_CONFIG}" <<EOF
database:
  url: "${DB_URL_DEFAULT}"
  schema: "${DB_SCHEMA}"
  username: "${DB_USER}"
  password: "${DB_PASSWORD}"

migrations:
  directory: "./migrations/core"
  directories:
    - "./migrations/features"
    - "./migrations/performance"
    - "./migrations/security"
    - "./logs/scenario-${SCENARIO_ID}/modules/inventory/migrations"
    - "./logs/scenario-${SCENARIO_ID}/modules/crm/migrations"
    - "./logs/scenario-${SCENARIO_ID}/modules/analytics/migrations"
  recursive: true

logging:
  level: INFO
  log_format: "text"
  log_dir: "./logs/scenario-${SCENARIO_ID}/modules/logs"
EOF

    run_dblift "Deploy all modules" migrate --config "${MULTI_CONFIG}"
    run_dblift "Inventory module-only deploy" migrate \
      --config "${MULTI_CONFIG}" \
      --tags inventory

    run_dblift "CRM module status" info \
      --config "${MULTI_CONFIG}" \
      --tags crm

    run_dblift "Validate inventory module migrations" validate-sql \
      "${MODULE_ROOT}/inventory/migrations/" \
      --dialect postgresql \
      --rules-file config/.dblift_rules.yaml

    append_summary "- ✅ Multi-directory configuration generated on the fly."
    append_summary "- ✅ Module-specific deployments executed with tags."
    append_summary "- ✅ Module migrations validated independently."
    ;;

  *)
    append_summary "❌ Scenario implementation not found."
    echo "Scenario ${SCENARIO_ID} is not implemented yet" >&2
    exit 1
    ;;
esac

append_summary ""
append_summary "✅ Scenario completed successfully."


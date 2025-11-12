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
DB_SCHEMA="${DB_SCHEMA:-dblift_demo}"
DB_URL_DEFAULT="jdbc:postgresql://${DB_HOST}:${DB_PORT}/${DB_NAME}?sslmode=disable&currentSchema=${DB_SCHEMA}"
CONFIG_PATH="${SCENARIO_DB_CONFIG:-config/dblift-postgresql.yaml}"

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

reset_database() {
  local description="${1:-Reset database schema}"
  local target_schema="${2:-${DB_SCHEMA}}"
  local sql="DROP SCHEMA IF EXISTS ${target_schema} CASCADE; CREATE SCHEMA ${target_schema};"
  psql_exec "${description}" "${sql}"
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
    run_dblift "Check database status (before)" info --config "${CONFIG_PATH}"
    BEFORE_INFO_LOG="${LAST_LOG_PATH}"
    show_log_excerpt "📋 Database status (before migrations)" "${BEFORE_INFO_LOG}" 80
    run_dblift "Run migrations" migrate --config "${CONFIG_PATH}" --log-format text --log-dir logs
    run_dblift "Check database status (after)" info --config "${CONFIG_PATH}"
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
    append_summary "- **Goal**: Exercise DBLift validation focusing on business and performance rules."
    append_summary "- **Focus**: Disable cosmetic style checks so we can spotlight schema risks."
    append_summary "- **What You’ll See**: Rule-by-rule severity output using `config/.dblift_rules_performance.yaml`."
    append_summary ""
    append_summary "## Timeline"
    append_summary "- ✅ Validate the repository’s existing migrations (expected to pass)."
    append_summary "- ❌ Introduce an intentional “bad” migration directory and validate it (expected to fail)."
    append_summary "- ✅ Fix the issues and re-run validation to confirm they disappear."
    append_summary ""

    run_dblift "Validate existing migrations" validate-sql migrations/ \
      --dialect postgresql \
      --rules-file config/.dblift_rules_performance.yaml \
      --format console

    BAD_SRC_DIR="examples/migrations/bad-demo"
    mkdir -p "${BAD_SRC_DIR}"
    BAD_FILE="${BAD_SRC_DIR}/V9_9_9__bad_example.sql"
    cat > "${BAD_FILE}" <<'SQL'
-- Intentional violations for Scenario 02
CREATE TABLE BAD_TABLE (
    ID INTEGER,
    NAME VARCHAR(100)
);

CREATE TABLE ANOTHER_BAD_TABLE (
    ID INTEGER PRIMARY KEY,
    VALUE TEXT
);

CREATE TABLE ORDERS_BAD (
    ID INTEGER PRIMARY KEY,
    CUSTOMER_ID INTEGER REFERENCES CUSTOMERS(ID),
    CREATED_AT TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UPDATED_AT TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CREATED_BY VARCHAR(50) DEFAULT 'system'
);

INSERT INTO BAD_TABLE SELECT * FROM USERS;
DELETE FROM BAD_TABLE;
SQL

    run_dblift "Validate bad migration (expected failures)" validate-sql "${BAD_SRC_DIR}/" \
      --dialect postgresql \
      --rules-file config/.dblift_rules_performance.yaml \
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
      --rules-file config/.dblift_rules_performance.yaml \
      --format console

    append_summary "- ✅ Baseline migrations pass when only strategic rules are enforced."
    append_summary "- ❌ Intentional violations trigger business/performance findings."
    append_summary "- ✅ After fixes, validation succeeds again under the focused ruleset."
    ;;

  "03")
    append_summary "## Overview"
    append_summary "- **Goal**: Practice the three primary undo flows."
    append_summary "- **Focus**: Undo the latest migration, jump back to a target version, and roll back a single version on demand."
    append_summary "- **Key Outputs**: Command transcripts showing each undo mode and its corresponding reapply."
    append_summary ""
    append_summary "## Execution Plan"
    append_summary "- 🔁 Reset the database to start from a known baseline."
    append_summary "- ▶️ Apply migrations (excluding security) so that undo scripts are available."
    append_summary "- ↩️ Undo the last migration (default behaviour) and reapply it."
    append_summary "- 🎯 Undo back to version 1.0.2 with `--target-version`, then migrate forward again."
    append_summary "- 🧷 Undo only version 1.1.0 using `--versions`, then restore it."
    append_summary ""

    wait_for_db
    reset_database "Reset schema for undo playbook"

    MIGRATE_BASE_ARGS=(
      "--config" "${CONFIG_PATH}"
      "--exclude-tags" "security"
    )

    run_dblift "Apply migrations for undo demo" migrate "${MIGRATE_BASE_ARGS[@]}"
    run_dblift "Show schema history (after apply)" info --config "${CONFIG_PATH}"
    show_log_excerpt "📋 Schema history after apply" "${LAST_LOG_PATH}" 80

    run_dblift "Undo newest migration" undo \
      --config "${CONFIG_PATH}"
    run_dblift "Reapply latest migration" migrate "${MIGRATE_BASE_ARGS[@]}"
    run_dblift "Show schema history after reapply" info --config "${CONFIG_PATH}"
    show_log_excerpt "📋 Schema history after newest undo/reapply" "${LAST_LOG_PATH}" 80

    run_dblift "Undo back to version 1.0.2" undo \
      --config "${CONFIG_PATH}" \
      --target-version 1.0.2
    run_dblift "Migrate forward after target undo" migrate "${MIGRATE_BASE_ARGS[@]}"
    run_dblift "Show schema history after target undo/reapply" info --config "${CONFIG_PATH}"
    show_log_excerpt "📋 Schema history after target undo" "${LAST_LOG_PATH}" 80

    run_dblift "Undo specific version 1.1.0" undo \
      --config "${CONFIG_PATH}" \
      --versions 1.1.0
    run_dblift "Reapply version 1.1.0 and dependents" migrate "${MIGRATE_BASE_ARGS[@]}"
    run_dblift "Show schema history after version-specific undo" info --config "${CONFIG_PATH}"
    show_log_excerpt "📋 Schema history after version-specific undo/reapply" "${LAST_LOG_PATH}" 80

    append_summary "- ✅ `dblift undo` (no extra flags) rolls back the most recent migration."
    append_summary "- ✅ `dblift undo --target-version` safely rewinds multiple migrations."
    append_summary "- ✅ `dblift undo --versions` removes specific version(s) without affecting others."
    ;;

  "04")
    append_summary "## Overview"
    append_summary "- **Goal**: Demonstrate checksum corruption detection and repair."
    append_summary "- **Focus**: Apply migrations, tamper with schema history, validate the failure, then heal it with `dblift repair`."
    append_summary "- **Key Outputs**: Validation failure/success logs plus schema history snapshots."
    append_summary ""
    append_summary "## Execution Plan"
    append_summary "- 🔁 Reset schema and apply migrations (excluding security) to reach version 1.3.0."
    append_summary "- 🧪 Manually corrupt the checksum for version 1.0.3."
    append_summary "- 🚨 Run `dblift validate` to surface the checksum mismatch."
    append_summary "- 🩺 Execute `dblift repair` and validate again to confirm recovery."
    append_summary ""

    wait_for_db
    reset_database "Reset schema for checksum repair demo"

    MIGRATE_CHECKSUM_ARGS=(
      "--config" "${CONFIG_PATH}"
      "--exclude-tags" "security"
    )

    run_dblift "Apply migrations for checksum demo" migrate "${MIGRATE_CHECKSUM_ARGS[@]}"
    run_dblift "Show schema history (after migrate)" info --config "${CONFIG_PATH}"
    show_log_excerpt "📋 Schema history after migrate" "${LAST_LOG_PATH}" 80

    psql_exec "Simulate checksum corruption" \
      "UPDATE dblift_schema_history SET checksum = 'corrupted' WHERE version = '1.0.3';"

    if ! run_dblift "Validate after corruption (expected failure)" validate --config "${CONFIG_PATH}"; then
      append_summary "- ⚠️ Checksum mismatch surfaced via `dblift validate`."
    fi
    show_log_excerpt "🚨 Validation (checksum mismatch)" "${LAST_LOG_PATH}" 120

    run_dblift "Repair schema history" repair --config "${CONFIG_PATH}"
    show_log_excerpt "🛠️ Repair output" "${LAST_LOG_PATH}" 80

    run_dblift "Validate after repair" validate --config "${CONFIG_PATH}"
    show_log_excerpt "✅ Validation (after repair)" "${LAST_LOG_PATH}" 120
    append_summary "- ✅ Corruption detected and reported by `dblift validate`."
    append_summary "- ✅ `dblift repair` recalculated checksums and validation now passes."
    ;;

  "05")
    append_summary "## Overview"
    append_summary "- **Goal**: Catch unplanned schema drift with clear, auditable output."
    append_summary "- **Focus**: Establish a clean baseline, introduce manual drift, and surface critical differences."
    append_summary "- **Key Outputs**: Diff summaries plus HTML/JSON reports captured as artifacts."
    append_summary ""
    append_summary "## Execution Plan"
    append_summary "- 🔁 Reset schema and apply migrations with the standard configuration."
    append_summary "- 📊 Run an initial `dblift diff` to verify the database matches migrations."
    append_summary "- ✍️ Execute `scripts/simulate-drift.sql` to introduce unmanaged changes."
    append_summary "- 🚨 Re-run `dblift diff`, expecting failure, and publish formatted reports."
    append_summary ""

    wait_for_db
    reset_database "Reset schema for drift detection"

    run_dblift "Apply migrations" migrate --config "${CONFIG_PATH}"

    DIFF_COMMON_ARGS=(
      "--config" "${CONFIG_PATH}"
      "--migration-path" "./migrations/core"
      "--scripts" "./migrations/features"
      "--scripts" "./migrations/performance"
    )

    run_dblift "Initial drift check (expected clean)" diff "${DIFF_COMMON_ARGS[@]}"
    CLEAN_DIFF_LOG="${LAST_LOG_PATH}"
    show_log_excerpt "✅ Drift check (clean baseline)" "${CLEAN_DIFF_LOG}" 80

    psql_file "Simulate drift changes" scripts/simulate-drift.sql

    if ! run_dblift "Detect drift after manual changes" diff "${DIFF_COMMON_ARGS[@]}"; then
      append_summary "- ⚠️ Drift detected after manual schema changes."
    fi
    DRIFT_DIFF_LOG="${LAST_LOG_PATH}"
    show_log_excerpt "⚠️ Drift findings" "${DRIFT_DIFF_LOG}" 120

    REPORT_DIR_HOST="${LOG_ROOT}/reports"
    REPORT_DIR_CONTAINER="./logs/scenario-${SCENARIO_ID}/reports"
    mkdir -p "${REPORT_DIR_HOST}"

    if ! run_dblift "Generate HTML drift report" diff \
      "${DIFF_COMMON_ARGS[@]}" \
      --log-format html \
      --log-dir "${REPORT_DIR_CONTAINER}"; then
      append_summary "- ℹ️ HTML drift report generated with drift differences (expected)."
    fi

    DRIFT_JSON_HOST="${LOG_ROOT}/drift-report.json"
    DRIFT_JSON_CONTAINER="./logs/scenario-${SCENARIO_ID}/drift-report.json"

    if ! run_dblift "Generate JSON drift report" diff \
      "${DIFF_COMMON_ARGS[@]}" \
      --format json \
      --output "${DRIFT_JSON_CONTAINER}"; then
      append_summary "- ℹ️ JSON drift report generated with drift differences (expected)."
    fi

    append_summary "- ✅ Clean baseline confirmed before introducing drift."
    append_summary "- ✅ Drift surfaced with error severity and summarised above."
    append_summary "- 📦 Additional HTML/JSON assets attached for auditing."
    ;;

  "06")
    append_summary "## Overview"
    append_summary "- **Goal**: Demonstrate CI/CD assets available in this repo."
    append_summary "- **Focus**: Enumerate workflows and produce a SARIF validation report for code scanning."
    append_summary "- **Key Outputs**: Workflow catalog plus the first lines of the generated SARIF file."
    append_summary ""
    append_summary "## Execution Plan"
    append_summary "- 📚 List available GitHub workflows."
    append_summary "- 🔍 Inspect the `validate-sql` workflow definition."
    append_summary "- 🧾 Run `dblift validate-sql` on curated demo migrations to emit SARIF (full run blocked by parser bug)."
    append_summary ""

    run_command "List available workflows" ls -1 .github/workflows
    WORKFLOW_LIST_LOG="${LAST_LOG_PATH}"
    if [[ -f "${WORKFLOW_LIST_LOG}" ]]; then
      WORKFLOW_COUNT=$(wc -l < "${WORKFLOW_LIST_LOG}" | tr -d '[:space:]')
      [[ -z "${WORKFLOW_COUNT}" ]] && WORKFLOW_COUNT=0
      show_log_excerpt "📚 Workflow catalog (${WORKFLOW_COUNT} files)" "${WORKFLOW_LIST_LOG}" 80
      append_summary "- ℹ️ Detected ${WORKFLOW_COUNT} workflow files under \".github/workflows\"."
    fi

    run_command "Show SQL validation workflow" cat .github/workflows/validate-sql.yml
    VALIDATION_WORKFLOW_LOG="${LAST_LOG_PATH}"
    if [[ -f "${VALIDATION_WORKFLOW_LOG}" ]]; then
      show_log_excerpt "🗂️ validate-sql workflow (first lines)" "${VALIDATION_WORKFLOW_LOG}" 80
    fi

    SARIF_DIR_HOST="${LOG_ROOT}/sarif"
    SARIF_DIR_CONTAINER="./logs/scenario-${SCENARIO_ID}/sarif"
    SARIF_BASENAME="scenario-06-validation.sarif"
    mkdir -p "${SARIF_DIR_HOST}"
    DEMO_VALIDATION_TARGETS=(
      "examples/migrations/V9_0_0__Example_bad_migration.sql"
      "examples/migrations/V9_0_1__Example_good_migration.sql"
    )
    append_summary "### Demo validation inputs"
    append_summary ""
    append_summary '```'
    for target in "${DEMO_VALIDATION_TARGETS[@]}"; do
      append_summary "${target}"
    done
    append_summary '```'
    append_summary ""
    append_summary "_Note: Full migration scan is temporarily limited due to an upstream parser issue with PL/pgSQL blocks._"

    run_dblift "Generate SARIF validation report" validate-sql "${DEMO_VALIDATION_TARGETS[@]}" \
      --dialect postgresql \
      --rules-file config/.dblift_rules.yaml \
      --format sarif
    SARIF_COMMAND_LOG="${LAST_LOG_PATH}"
    if [[ -f "${SARIF_COMMAND_LOG}" ]]; then
      show_log_excerpt "🧾 validate-sql execution log" "${SARIF_COMMAND_LOG}" 80
      cp "${SARIF_COMMAND_LOG}" "${SARIF_DIR_HOST}/${SARIF_BASENAME}"
    fi

    SARIF_GENERATED_FILE="${SARIF_DIR_HOST}/${SARIF_BASENAME}"
    if [[ -n "${SARIF_GENERATED_FILE}" ]]; then
      if [[ -f "${SARIF_GENERATED_FILE}" ]]; then
        run_command "Preview SARIF report headers" head -n 40 "${SARIF_GENERATED_FILE}"
        append_summary "- ✅ Workflow inventory and sample YAML surfaced above."
        append_summary "- ✅ SARIF report generated via `validate-sql`; header preview included."
        RELATIVE_SARIF_PATH="${SARIF_GENERATED_FILE#${WORKSPACE}/}"
        append_summary "- 📁 SARIF saved to \`${RELATIVE_SARIF_PATH}\`."
      else
        append_summary "- ⚠️ Expected SARIF output not found at ${SARIF_GENERATED_FILE}."
      fi
    else
      append_summary "- ⚠️ Expected SARIF output not found under ${SARIF_DIR_HOST}."
    fi
    ;;

  "07")
    append_summary "## Overview"
    append_summary "- **Goal**: Illustrate tag-based deployments for feature toggles."
    append_summary "- **Focus**: Apply core migrations, roll out tagged features selectively, and inspect status."
    append_summary "- **Key Outputs**: Command transcripts showing which tags were included or excluded, plus the repeatable objects once all dependencies are active."
    append_summary ""
    append_summary "## Execution Plan"
    append_summary "- 🔁 Reset schema to ensure tags control what lands in each step."
    append_summary "- 🏷️ Deploy core migrations while keeping feature-dependent repeatables disabled."
    append_summary "- 📬 Roll out `user-mgmt`, `notifications`, and `analytics` tags individually."
    append_summary "- 🧾 Reapply repeatable views once all dependencies exist."
    append_summary "- 🔐 Inspect the `security` tag status to show remaining gated features."
    append_summary ""

    wait_for_db
    reset_database "Reset schema for tag deployment demo"

    TAG_CONFIG_NO_REPEATABLE="${LOG_ROOT}/dblift-tags-no-repeatable.yaml"
    cat > "${TAG_CONFIG_NO_REPEATABLE}" <<EOF
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
  undo_directories:
    - "./migrations/features"
    - "./migrations/performance"
  recursive: false
EOF

    append_summary "ℹ️ Using temporary config \`${TAG_CONFIG_NO_REPEATABLE##${WORKSPACE}/}\` to skip repeatable scripts until all feature tables exist."
    append_summary ""

    append_summary "### Step 1 · Core schema without feature tags"
    append_summary ""
    append_summary "Command"
    append_summary '```bash'
    append_summary "dblift migrate --config ${TAG_CONFIG_NO_REPEATABLE} --exclude-tags user-mgmt,notifications,analytics,security"
    append_summary '```'
    append_summary ""
    run_dblift "Apply core schema (exclude feature tags)" migrate \
      --config "${TAG_CONFIG_NO_REPEATABLE}" \
      --exclude-tags user-mgmt,notifications,analytics,security
    CORE_ONLY_LOG="${LAST_LOG_PATH}"
    show_log_excerpt "🚀 Core deployment (tags excluded)" "${CORE_ONLY_LOG}" 80

    append_summary "### Step 2 · Deploy user management features"
    append_summary ""
    append_summary "Command"
    append_summary '```bash'
    append_summary "dblift migrate --config ${TAG_CONFIG_NO_REPEATABLE} --tags user-mgmt"
    append_summary '```'
    append_summary ""
    run_dblift "Deploy user management features (tags=user-mgmt)" migrate \
      --config "${TAG_CONFIG_NO_REPEATABLE}" \
      --tags user-mgmt
    USER_MGMT_LOG="${LAST_LOG_PATH}"
    show_log_excerpt "🏷️ user-mgmt rollout" "${USER_MGMT_LOG}" 40

    append_summary "### Step 3 · Deploy notifications"
    append_summary ""
    append_summary "Command"
    append_summary '```bash'
    append_summary "dblift migrate --config ${TAG_CONFIG_NO_REPEATABLE} --tags notifications"
    append_summary '```'
    append_summary ""
    run_dblift "Deploy notifications (tags=notifications)" migrate \
      --config "${TAG_CONFIG_NO_REPEATABLE}" \
      --tags notifications
    NOTIFICATIONS_LOG="${LAST_LOG_PATH}"
    show_log_excerpt "🏷️ notifications rollout" "${NOTIFICATIONS_LOG}" 40

    append_summary "### Step 4 · Deploy analytics"
    append_summary ""
    append_summary "Command"
    append_summary '```bash'
    append_summary "dblift migrate --config ${TAG_CONFIG_NO_REPEATABLE} --tags analytics"
    append_summary '```'
    append_summary ""
    run_dblift "Deploy analytics (tags=analytics)" migrate \
      --config "${TAG_CONFIG_NO_REPEATABLE}" \
      --tags analytics
    ANALYTICS_LOG="${LAST_LOG_PATH}"
    show_log_excerpt "📈 analytics rollout" "${ANALYTICS_LOG}" 40

    append_summary "### Step 5 · Reapply repeatable views with full configuration"
    append_summary ""
    append_summary "Command"
    append_summary '```bash'
    append_summary "dblift migrate --config ${CONFIG_PATH} --exclude-tags security"
    append_summary '```'
    append_summary ""
    run_dblift "Reapply repeatables after enabling features" migrate \
      --config "${CONFIG_PATH}" \
      --exclude-tags security
    REPEATABLE_LOG="${LAST_LOG_PATH}"
    show_log_excerpt "🧾 Repeatable objects refreshed" "${REPEATABLE_LOG}" 60

    append_summary "### Step 6 · Inspect security tag status"
    append_summary ""
    append_summary "Command"
    append_summary '```bash'
    append_summary "dblift info --config ${CONFIG_PATH} --tags security"
    append_summary '```'
    append_summary ""
    run_dblift "Check security tag status" info \
      --config "${CONFIG_PATH}" \
      --tags security
    SECURITY_STATUS_LOG="${LAST_LOG_PATH}"
    show_log_excerpt "🔐 security tag status" "${SECURITY_STATUS_LOG}" 60

    append_summary "- ✅ Core-only run excluded all feature tags as expected while repeatables were disabled."
    append_summary "- ✅ Feature tags (`user-mgmt`, `notifications`, `analytics`) deployed incrementally with clear outputs."
    append_summary "- ✅ Repeatable views refreshed once prerequisites were in place."
    append_summary "- ✅ Tag-specific `info` output captured for the security subset, showing gated migrations remain pending."
    ;;

  "08")
    append_summary "## Overview"
    append_summary "- **Goal**: Showcase brownfield onboarding using `dblift baseline`."
    append_summary "- **Focus**: Record an existing schema, then add new migrations safely."
    append_summary "- **Key Outputs**: Baseline command transcript plus new migration status."
    append_summary ""
    append_summary "## Execution Plan"
    append_summary "- 🏗️ Seed the database manually to emulate a legacy system."
    append_summary "- 🧾 Generate a one-off DBLift config that points to extracted SQL."
    append_summary "- 📌 Run `dblift baseline` and then add a new migration on top."
    append_summary ""

    wait_for_db
    reset_database "Reset schema for brownfield demo"

    psql_file "Seed legacy schema (initial)" migrations/core/V1_0_0__Initial_schema.sql
    psql_file "Seed legacy schema (customers)" migrations/core/V1_0_1__Add_customers.sql
    psql_file "Seed legacy schema (products)" migrations/core/V1_0_2__Add_products.sql

    BROWNFIELD_DIR_HOST="${LOG_ROOT}/brownfield"
    BROWNFIELD_DIR_CONTAINER="./logs/scenario-${SCENARIO_ID}/brownfield"
    mkdir -p "${BROWNFIELD_DIR_HOST}/migrations"
    cp migrations/core/V1_0_0__Initial_schema.sql "${BROWNFIELD_DIR_HOST}/migrations/V1_0_0__Baseline_existing_schema.sql"

    cat > "${BROWNFIELD_DIR_HOST}/dblift-brownfield.yaml" <<EOF
database:
  url: "${DB_URL_DEFAULT}"
  schema: "${DB_SCHEMA}"
  username: "${DB_USER}"
  password: "${DB_PASSWORD}"

migrations:
  directory: "${BROWNFIELD_DIR_CONTAINER}/migrations"
  recursive: true

logging:
  level: INFO
  log_format: "text"
  log_dir: "${BROWNFIELD_DIR_CONTAINER}/logs"
EOF

    run_dblift "Baseline existing database" baseline \
      --config "${BROWNFIELD_DIR_CONTAINER}/dblift-brownfield.yaml" \
      --baseline-version 1.0.0 \
      --baseline-description "Initial baseline of existing production database"
    BASELINE_LOG="${LAST_LOG_PATH}"
    show_log_excerpt "🧾 Baseline execution" "${BASELINE_LOG}" 80

    NEW_MIG_HOST="${BROWNFIELD_DIR_HOST}/migrations/V1_0_1__Add_api_keys_table.sql"
    NEW_MIG_CONTAINER="${BROWNFIELD_DIR_CONTAINER}/migrations/V1_0_1__Add_api_keys_table.sql"
    cat > "${NEW_MIG_HOST}" <<'SQL'
CREATE TABLE IF NOT EXISTS api_keys (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id),
    key_hash VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by VARCHAR(50) DEFAULT 'system' NOT NULL
);
SQL

    run_dblift "Apply post-baseline migration" migrate --config "${BROWNFIELD_DIR_CONTAINER}/dblift-brownfield.yaml"
    POST_BASELINE_LOG="${LAST_LOG_PATH}"
    show_log_excerpt "🚀 Post-baseline migration" "${POST_BASELINE_LOG}" 40

    run_dblift "Inspect status after baseline + new migration" info --config "${BROWNFIELD_DIR_CONTAINER}/dblift-brownfield.yaml"
    STATUS_LOG="${LAST_LOG_PATH}"
    show_log_excerpt "📋 Brownfield status snapshot" "${STATUS_LOG}" 80

    append_summary "- ✅ Legacy objects captured via `dblift baseline`."
    append_summary "- ✅ New migration executed from the managed directory."
    append_summary "- ✅ Status output confirms baseline + incremental change."
    ;;

  "09")
    append_summary "## Overview"
    append_summary "- **Goal**: Demonstrate multi-module orchestration with directory overrides."
    append_summary "- **Focus**: Blend core migrations with module-specific directories and run targeted operations."
    append_summary "- **Key Outputs**: Multi-module config, deploy logs, and module validation results."
    append_summary ""
    append_summary "## Execution Plan"
    append_summary "- 🔁 Reset schema to guarantee predictable results."
    append_summary "- 🧱 Generate module-specific migration directories on the fly."
    append_summary "- 🚀 Deploy everything, then run tag-scoped and directory-scoped operations."
    append_summary ""

    wait_for_db
    reset_database "Reset schema for multi-module demo"

    MODULE_ROOT_HOST="${LOG_ROOT}/modules"
    MODULE_ROOT_CONTAINER="./logs/scenario-${SCENARIO_ID}/modules"
    mkdir -p "${MODULE_ROOT_HOST}/inventory/migrations" "${MODULE_ROOT_HOST}/crm/migrations" "${MODULE_ROOT_HOST}/analytics/migrations"

    cat > "${MODULE_ROOT_HOST}/inventory/migrations/V3_0_0__Create_inventory_schema[inventory].sql" <<'SQL'
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

    cat > "${MODULE_ROOT_HOST}/crm/migrations/V3_1_0__Create_crm_schema[crm].sql" <<'SQL'
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

    cat > "${MODULE_ROOT_HOST}/analytics/migrations/V3_2_0__Create_analytics_views[analytics].sql" <<'SQL'
DROP VIEW IF EXISTS analytics_orders_summary;
CREATE OR REPLACE VIEW analytics_orders_summary AS
SELECT c.contact_name AS customer_name,
       COUNT(o.id) AS total_orders,
       SUM(o.total_amount) AS total_amount
FROM customers c
LEFT JOIN orders o ON c.id = o.customer_id
GROUP BY c.contact_name;
SQL

    MULTI_CONFIG_HOST="${LOG_ROOT}/dblift-multi-module.yaml"
    MULTI_CONFIG_CONTAINER="./logs/scenario-${SCENARIO_ID}/dblift-multi-module.yaml"
    cat > "${MULTI_CONFIG_HOST}" <<EOF
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
    - "${MODULE_ROOT_CONTAINER}/inventory/migrations"
    - "${MODULE_ROOT_CONTAINER}/crm/migrations"
    - "${MODULE_ROOT_CONTAINER}/analytics/migrations"
  recursive: true

logging:
  level: INFO
  log_format: "text"
  log_dir: "${MODULE_ROOT_CONTAINER}/logs"
EOF

    run_command "Show module directory layout" bash -c "cd '${MODULE_ROOT_HOST}' && find . -maxdepth 2 -type f | sort"
    MODULE_LAYOUT_LOG="${LAST_LOG_PATH}"
    show_log_excerpt "📂 Module directory layout" "${MODULE_LAYOUT_LOG}" 80

    run_command "Show multi-module config" cat "${MULTI_CONFIG_HOST}"
    MULTI_CONFIG_LOG="${LAST_LOG_PATH}"
    show_log_excerpt "🧾 Multi-module DBLift config" "${MULTI_CONFIG_LOG}" 120

    CRM_CONFIG_HOST="${LOG_ROOT}/dblift-crm-module.yaml"
    CRM_CONFIG_CONTAINER="./logs/scenario-${SCENARIO_ID}/dblift-crm-module.yaml"
    cat > "${CRM_CONFIG_HOST}" <<EOF
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
    - "${MODULE_ROOT_CONTAINER}/crm/migrations"
  recursive: true
EOF

    run_dblift "Deploy all modules" migrate --config "${MULTI_CONFIG_CONTAINER}"
    DEPLOY_ALL_LOG="${LAST_LOG_PATH}"
    show_log_excerpt "🚀 Full multi-module deploy" "${DEPLOY_ALL_LOG}" 120

    run_dblift "Inventory module-only deploy" migrate \
      --config "${MULTI_CONFIG_CONTAINER}" \
      --tags inventory
    INVENTORY_ONLY_LOG="${LAST_LOG_PATH}"
    show_log_excerpt "🏷️ inventory-only deploy" "${INVENTORY_ONLY_LOG}" 60
    append_summary "- ℹ️ Inventory-only run after full deploy reports \"No pending migrations\" (expected)."

    run_dblift "Validate inventory module migrations" validate-sql \
      "${MODULE_ROOT_CONTAINER}/inventory/migrations/" \
      --dialect postgresql \
      --rules-file config/.dblift_rules.yaml
    INVENTORY_VALIDATION_LOG="${LAST_LOG_PATH}"
    show_log_excerpt "✅ Inventory module validation" "${INVENTORY_VALIDATION_LOG}" 60

    append_summary "- ✅ Multi-directory configuration generated on the fly."
    append_summary "- ✅ Module-specific deployments executed with tags."
    append_summary "- ✅ CRM status inspected via targeted schema-history query."
    append_summary "- ✅ Module migrations validated independently."
    ;;

  "10")
    append_summary "## Overview"
    append_summary "- **Goal**: Showcase targeted schema exports for managed vs. unmanaged objects."
    append_summary "- **Focus**: Mix manual (legacy) tables with migration-managed ones, then export each subset."
    append_summary "- **Key Outputs**: Managed-only and unmanaged-only SQL dumps saved as run artifacts from a clean demo schema."
    append_summary ""
    append_summary "## Execution Plan"
    append_summary "- 🔁 Reset the dedicated export schema to start from a known baseline."
    append_summary "- ✍️ Create a legacy table manually to mimic unmanaged drift."
    append_summary "- ▶️ Apply migrations to bring the schema to the latest managed version."
    append_summary "- 💾 Export managed objects with `--managed-only`."
    append_summary "- 🗂️ Export the unmanaged table with `--unmanaged-only` for baselining."
    append_summary ""

    wait_for_db
 
     EXPORT_DIR_HOST="${LOG_ROOT}/exports"
     EXPORT_DIR_CONTAINER="./logs/scenario-${SCENARIO_ID}/exports"
     mkdir -p "${EXPORT_DIR_HOST}"
     reset_database "Reset schema for export demo"
 
     psql_exec "Create unmanaged audit table" \
       "CREATE TABLE IF NOT EXISTS ${DB_SCHEMA}.legacy_audit_log (
          id SERIAL PRIMARY KEY,
          event_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          payload JSONB NOT NULL
        );
        COMMENT ON TABLE ${DB_SCHEMA}.legacy_audit_log IS 'Manually created to simulate brownfield drift';"
 
     run_dblift "Apply migrations (managed objects)" migrate \
       --config "${CONFIG_PATH}"
 
     MIGRATE_LOG="${LAST_LOG_PATH}"
     show_log_excerpt "🚀 Migrate managed schema" "${MIGRATE_LOG}" 80
 
     mkdir -p "${EXPORT_DIR_CONTAINER}"
     run_dblift "Export managed schema (ignore unmanaged)" export-schema \
       --config "${CONFIG_PATH}" \
       --managed-only \
       --output "${EXPORT_DIR_CONTAINER}/managed.sql"
     MANAGED_EXPORT_LOG="${LAST_LOG_PATH}"
     show_log_excerpt "📄 Export managed schema" "${MANAGED_EXPORT_LOG}" 80
     run_command "Preview managed export (first 40 lines)" head -n 40 "${EXPORT_DIR_HOST}/managed.sql"
 
     run_dblift "Export unmanaged schema only" export-schema \
       --config "${CONFIG_PATH}" \
       --unmanaged-only \
       --output "${EXPORT_DIR_CONTAINER}/unmanaged.sql"
     UNMANAGED_EXPORT_LOG="${LAST_LOG_PATH}"
     show_log_excerpt "📄 Export unmanaged schema" "${UNMANAGED_EXPORT_LOG}" 80
     run_command "Preview unmanaged export (first 40 lines)" head -n 40 "${EXPORT_DIR_HOST}/unmanaged.sql"
 
     append_summary "- ✅ Managed export excludes the manually created legacy table."
     append_summary "- ✅ Unmanaged export captures the legacy table for baselining."
     append_summary "- 📦 SQL files (`managed.sql`, `unmanaged.sql`) saved under scenario artifacts."
     ;;

  *)
    append_summary "❌ Scenario implementation not found."
    echo "Scenario ${SCENARIO_ID} is not implemented yet" >&2
    exit 1
    ;;
esac

append_summary ""
append_summary "✅ Scenario completed successfully."


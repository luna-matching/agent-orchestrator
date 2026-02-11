#!/bin/bash
set -euo pipefail

# Redash API Query Tool
# Usage:
#   ./query.sh <query_id>                          # Get latest result (JSON)
#   ./query.sh <query_id> '{"p_key":"value"}'      # With parameters
#   ./query.sh <query_id> '' csv                   # CSV output
#   ./query.sh <query_id> '{"p_key":"value"}' csv  # Parameters + CSV

QUERY_ID="${1:?Usage: query.sh <query_id> [params_json] [csv]}"
PARAMS="${2:-}"
FORMAT="${3:-json}"

# Environment check
: "${REDASH_BASE_URL:?Set REDASH_BASE_URL (e.g. https://redash.example.com)}"
: "${REDASH_API_KEY:?Set REDASH_API_KEY}"

API="${REDASH_BASE_URL}/api"
AUTH="Key ${REDASH_API_KEY}"
OUTPUT_DIR="artifacts/redash"
mkdir -p "${OUTPUT_DIR}"

TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Trigger query execution with parameters if provided
if [ -n "${PARAMS}" ]; then
  echo "Triggering query ${QUERY_ID} with parameters..."
  RESULT=$(curl -sf \
    -H "Authorization: ${AUTH}" \
    -H "Content-Type: application/json" \
    -d "{\"parameters\": ${PARAMS}}" \
    "${API}/queries/${QUERY_ID}/results" 2>/dev/null) || {
    echo "ERROR: Failed to execute query ${QUERY_ID}" >&2
    exit 1
  }

  JOB_ID=$(echo "${RESULT}" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('job',{}).get('id',''))" 2>/dev/null || echo "")

  if [ -n "${JOB_ID}" ]; then
    echo "Waiting for job ${JOB_ID}..."
    for i in $(seq 1 30); do
      sleep 2
      JOB_STATUS=$(curl -sf \
        -H "Authorization: ${AUTH}" \
        "${API}/jobs/${JOB_ID}" 2>/dev/null) || continue
      STATUS=$(echo "${JOB_STATUS}" | python3 -c "import sys,json; print(json.load(sys.stdin).get('job',{}).get('status',0))" 2>/dev/null || echo "0")
      if [ "${STATUS}" = "3" ]; then
        QUERY_RESULT_ID=$(echo "${JOB_STATUS}" | python3 -c "import sys,json; print(json.load(sys.stdin).get('job',{}).get('query_result_id',''))" 2>/dev/null || echo "")
        break
      elif [ "${STATUS}" = "4" ]; then
        echo "ERROR: Query execution failed" >&2
        exit 1
      fi
    done
  fi
fi

# Fetch results
if [ "${FORMAT}" = "csv" ]; then
  OUTPUT_FILE="${OUTPUT_DIR}/query_${QUERY_ID}_${TIMESTAMP}.csv"
  curl -sf \
    -H "Authorization: ${AUTH}" \
    "${API}/queries/${QUERY_ID}/results.csv" \
    -o "${OUTPUT_FILE}" || {
    echo "ERROR: Failed to fetch CSV for query ${QUERY_ID}" >&2
    exit 1
  }
else
  OUTPUT_FILE="${OUTPUT_DIR}/query_${QUERY_ID}_${TIMESTAMP}.json"
  curl -sf \
    -H "Authorization: ${AUTH}" \
    "${API}/queries/${QUERY_ID}/results.json" \
    -o "${OUTPUT_FILE}" || {
    echo "ERROR: Failed to fetch JSON for query ${QUERY_ID}" >&2
    exit 1
  }
fi

echo "Saved: ${OUTPUT_FILE}"
echo "Query ID: ${QUERY_ID}"
echo "Format: ${FORMAT}"
echo "Timestamp: ${TIMESTAMP}"

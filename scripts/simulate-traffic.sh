#!/usr/bin/env bash

set -euo pipefail

BASE_URL="${BASE_URL:-https://guytho1996-petclinic.eastus2.cloudapp.azure.com}"
DURATION_SECONDS="${DURATION_SECONDS:-300}"
CONCURRENCY="${CONCURRENCY:-4}"
MIN_SLEEP_MS="${MIN_SLEEP_MS:-100}"
MAX_SLEEP_MS="${MAX_SLEEP_MS:-1200}"
REQUEST_TIMEOUT_SECONDS="${REQUEST_TIMEOUT_SECONDS:-10}"
INCLUDE_ERRORS="${INCLUDE_ERRORS:-false}"
ERROR_PERCENT="${ERROR_PERCENT:-0}"
INSECURE_TLS="${INSECURE_TLS:-false}"

usage() {
  cat <<'USAGE'
Usage:
  scripts/simulate-traffic.sh [options]

Options:
  -u, --url URL             Base URL to hit.
                            Default: https://guytho1996-petclinic.eastus2.cloudapp.azure.com
  -d, --duration SECONDS    Test duration. Default: 300
  -c, --concurrency N       Number of parallel workers. Default: 4
  --min-sleep MS            Minimum wait between requests per worker. Default: 100
  --max-sleep MS            Maximum wait between requests per worker. Default: 1200
  --timeout SECONDS         Per-request timeout. Default: 10
  --include-errors          Include synthetic error traffic.
  --error-percent N         Percent of requests sent to an error endpoint when --include-errors is set.
                            Default: 0
  -k, --insecure            Skip TLS certificate verification.
  -h, --help                Show this help.

Examples:
  scripts/simulate-traffic.sh
  scripts/simulate-traffic.sh --duration 600 --concurrency 8
  scripts/simulate-traffic.sh --url https://example.com --duration 120
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -u|--url)
      BASE_URL="${2:?missing URL}"
      shift 2
      ;;
    -d|--duration)
      DURATION_SECONDS="${2:?missing duration}"
      shift 2
      ;;
    -c|--concurrency)
      CONCURRENCY="${2:?missing concurrency}"
      shift 2
      ;;
    --min-sleep)
      MIN_SLEEP_MS="${2:?missing minimum sleep}"
      shift 2
      ;;
    --max-sleep)
      MAX_SLEEP_MS="${2:?missing maximum sleep}"
      shift 2
      ;;
    --timeout)
      REQUEST_TIMEOUT_SECONDS="${2:?missing timeout}"
      shift 2
      ;;
    --include-errors)
      INCLUDE_ERRORS="true"
      shift
      ;;
    --error-percent)
      ERROR_PERCENT="${2:?missing error percent}"
      shift 2
      ;;
    -k|--insecure)
      INSECURE_TLS="true"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

require_integer() {
  local name="$1"
  local value="$2"
  if ! [[ "$value" =~ ^[0-9]+$ ]]; then
    echo "$name must be an integer: $value" >&2
    exit 2
  fi
}

require_integer "DURATION_SECONDS" "$DURATION_SECONDS"
require_integer "CONCURRENCY" "$CONCURRENCY"
require_integer "MIN_SLEEP_MS" "$MIN_SLEEP_MS"
require_integer "MAX_SLEEP_MS" "$MAX_SLEEP_MS"
require_integer "REQUEST_TIMEOUT_SECONDS" "$REQUEST_TIMEOUT_SECONDS"
require_integer "ERROR_PERCENT" "$ERROR_PERCENT"

if (( DURATION_SECONDS < 1 || CONCURRENCY < 1 || REQUEST_TIMEOUT_SECONDS < 1 )); then
  echo "duration, concurrency, and timeout must be greater than zero" >&2
  exit 2
fi

if (( MIN_SLEEP_MS > MAX_SLEEP_MS )); then
  echo "min sleep must be lower than or equal to max sleep" >&2
  exit 2
fi

if (( ERROR_PERCENT > 100 )); then
  echo "error percent must be between 0 and 100" >&2
  exit 2
fi

if ! command -v curl >/dev/null 2>&1; then
  echo "curl is required" >&2
  exit 127
fi

BASE_URL="${BASE_URL%/}"

endpoints=(
  "/"
  "/owners"
  "/owners?lastName="
  "/owners?lastName=Davis"
  "/owners?lastName=Franklin"
  "/owners/1"
  "/owners/2"
  "/vets.html"
  "/resources/css/petclinic.css"
)

error_endpoints=(
  "/oups"
  "/__missing-page-for-slo-test"
)

curl_args=(
  --silent
  --show-error
  --output /dev/null
  --max-time "$REQUEST_TIMEOUT_SECONDS"
  --write-out '%{http_code}\t%{time_total}\t%{url_effective}\n'
)

if [[ "$INSECURE_TLS" == "true" ]]; then
  curl_args+=(--insecure)
fi

results_file="$(mktemp)"
stop_file="$(mktemp)"
rm -f "$stop_file"

cleanup() {
  rm -f "$results_file" "$stop_file"
}
trap cleanup EXIT

sleep_randomly() {
  local range=$((MAX_SLEEP_MS - MIN_SLEEP_MS + 1))
  local sleep_ms=$((MIN_SLEEP_MS + RANDOM % range))
  sleep "$(awk -v ms="$sleep_ms" 'BEGIN { printf "%.3f", ms / 1000 }')"
}

pick_endpoint() {
  if [[ "$INCLUDE_ERRORS" == "true" ]] && (( ERROR_PERCENT > 0 )) && (( RANDOM % 100 < ERROR_PERCENT )); then
    printf '%s\n' "${error_endpoints[$((RANDOM % ${#error_endpoints[@]}))]}"
    return
  fi
  printf '%s\n' "${endpoints[$((RANDOM % ${#endpoints[@]}))]}"
}

worker() {
  local worker_id="$1"
  local end_epoch="$2"
  local endpoint
  local output
  local status
  local now

  while [[ ! -f "$stop_file" ]]; do
    now="$(date +%s)"
    if (( now >= end_epoch )); then
      break
    fi

    endpoint="$(pick_endpoint)"
    if output="$(curl "${curl_args[@]}" "${BASE_URL}${endpoint}" 2>/dev/null)"; then
      printf '%s\t%s\n' "$worker_id" "$output" >> "$results_file"
    else
      status="$?"
      printf '%s\tcurl_error_%s\t0\t%s%s\n' "$worker_id" "$status" "$BASE_URL" "$endpoint" >> "$results_file"
    fi

    sleep_randomly
  done
}

start_epoch="$(date +%s)"
end_epoch=$((start_epoch + DURATION_SECONDS))

cat <<EOF
Simulating Petclinic traffic
  URL:             $BASE_URL
  Duration:        ${DURATION_SECONDS}s
  Concurrency:     $CONCURRENCY
  Sleep:           ${MIN_SLEEP_MS}-${MAX_SLEEP_MS}ms per worker
  Timeout:         ${REQUEST_TIMEOUT_SECONDS}s
  Include errors:  $INCLUDE_ERRORS
  Error percent:   $ERROR_PERCENT
EOF

pids=()
for worker_id in $(seq 1 "$CONCURRENCY"); do
  worker "$worker_id" "$end_epoch" &
  pids+=("$!")
done

trap 'touch "$stop_file"; wait "${pids[@]}" 2>/dev/null || true; cleanup; exit 130' INT TERM

while (( "$(date +%s)" < end_epoch )); do
  sleep 5
  total="$(wc -l < "$results_file" | tr -d ' ')"
  echo "Requests so far: $total"
done

touch "$stop_file"
wait "${pids[@]}"

echo
echo "Summary"
awk -F '\t' '
  BEGIN {
    total = 0; ok2 = 0; redir3 = 0; client4 = 0; server5 = 0; curl_errors = 0; latency_sum = 0;
  }
  {
    total++;
    status = $2;
    latency = $3 + 0;
    latency_sum += latency;
    if (status ~ /^2/) ok2++;
    else if (status ~ /^3/) redir3++;
    else if (status ~ /^4/) client4++;
    else if (status ~ /^5/) server5++;
    else if (status ~ /^curl_error_/) curl_errors++;
  }
  END {
    avg = total > 0 ? latency_sum / total : 0;
    printf "  Total requests:      %d\n", total;
    printf "  2xx responses:       %d\n", ok2;
    printf "  3xx responses:       %d\n", redir3;
    printf "  4xx responses:       %d\n", client4;
    printf "  5xx responses:       %d\n", server5;
    printf "  Curl errors:         %d\n", curl_errors;
    printf "  Average latency:     %.3fs\n", avg;
  }
' "$results_file"

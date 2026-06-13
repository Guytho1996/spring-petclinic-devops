#!/usr/bin/env bash
set -euo pipefail

dist_dir="${1:-dist/pages}"
frontend_dir="frontend"

json_escape() {
  local value="${1:-}"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  value="${value//$'\n'/\\n}"
  value="${value//$'\r'/}"
  printf '%s' "$value"
}

rm -rf "$dist_dir"
mkdir -p "$dist_dir/assets"

cp "$frontend_dir/index.html" "$dist_dir/index.html"
cp "$frontend_dir/assets/site.css" "$dist_dir/assets/site.css"
cp "$frontend_dir/assets/app.js" "$dist_dir/assets/app.js"
cp src/main/resources/static/resources/images/pets.png "$dist_dir/assets/pets.png"
cp src/main/resources/static/resources/images/favicon.png "$dist_dir/assets/favicon.png"

cat > "$dist_dir/config.js" <<CONFIG
window.PETCLINIC_CONFIG = {
  environment: "$(json_escape "${PAGES_APP_ENV:-production}")",
  backendBaseUrl: "$(json_escape "${PAGES_BACKEND_BASE_URL:-}")",
  gitSha: "$(json_escape "${GITHUB_SHA:-local}")",
  deployedAt: "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
};
CONFIG

find "$dist_dir" -maxdepth 3 -type f -print | sort

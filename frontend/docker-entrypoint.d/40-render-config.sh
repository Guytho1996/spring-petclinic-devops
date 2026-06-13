#!/bin/sh
set -eu

json_escape() {
  printf '%s' "${1:-}" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

cat > /usr/share/nginx/html/config.js <<CONFIG
window.PETCLINIC_CONFIG = {
  environment: "$(json_escape "${FRONTEND_APP_ENV:-production}")",
  backendBaseUrl: "$(json_escape "${FRONTEND_BACKEND_BASE_URL:-same-origin}")",
  gitSha: "$(json_escape "${FRONTEND_GIT_SHA:-local}")",
  deployedAt: "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
};
CONFIG

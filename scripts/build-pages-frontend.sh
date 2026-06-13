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

normalize_base_path() {
  local value="${1:-/}"
  if [[ "$value" != /* ]]; then
    value="/$value"
  fi
  if [[ "$value" != */ ]]; then
    value="$value/"
  fi
  printf '%s' "$value"
}

frontend_base_path="${PAGES_FRONTEND_BASE_PATH:-}"
if [[ -z "$frontend_base_path" && -n "${GITHUB_REPOSITORY:-}" ]]; then
  frontend_base_path="/${GITHUB_REPOSITORY##*/}/"
fi
frontend_base_path="$(normalize_base_path "${frontend_base_path:-/}")"

backend_base_url="${PAGES_BACKEND_BASE_URL:-}"
backend_base_url="${backend_base_url%/}"
owners_target_url=""
if [[ -n "$backend_base_url" ]]; then
  owners_target_url="$backend_base_url/owners/find"
fi

rm -rf "$dist_dir"
mkdir -p "$dist_dir/assets" "$dist_dir/owners" "$dist_dir/owners/find"

cp "$frontend_dir/index.html" "$dist_dir/index.html"
cp "$frontend_dir/owners/index.html" "$dist_dir/owners/index.html"
cp "$frontend_dir/assets/site.css" "$dist_dir/assets/site.css"
cp "$frontend_dir/assets/app.js" "$dist_dir/assets/app.js"
cp src/main/resources/static/resources/images/pets.png "$dist_dir/assets/pets.png"
cp src/main/resources/static/resources/images/favicon.png "$dist_dir/assets/favicon.png"

cat > "$dist_dir/config.js" <<CONFIG
window.PETCLINIC_CONFIG = {
  environment: "$(json_escape "${PAGES_APP_ENV:-production}")",
  frontendBasePath: "$(json_escape "$frontend_base_path")",
  backendBaseUrl: "$(json_escape "${PAGES_BACKEND_BASE_URL:-}")",
  gitSha: "$(json_escape "${GITHUB_SHA:-local}")",
  deployedAt: "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
};
CONFIG

cat > "$dist_dir/owners/find/index.html" <<CONFIG
<!doctype html>
<html lang="es">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Petclinic Owners</title>
    <style>
      body {
        color: #1f2937;
        font-family: system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
        margin: 2rem;
      }
      a {
        color: #2563eb;
      }
    </style>
  </head>
  <body>
    <p>Abriendo Petclinic...</p>
    <a id="target-link" href="$(json_escape "$frontend_base_path")">Abrir Petclinic</a>
    <script>
      (function () {
        "use strict";
        var targetUrl = "$(json_escape "$owners_target_url")";
        var link = document.getElementById("target-link");
        if (targetUrl) {
          link.href = targetUrl;
          window.location.replace(targetUrl);
        }
      }());
    </script>
  </body>
</html>
CONFIG

find "$dist_dir" -maxdepth 3 -type f -print | sort
